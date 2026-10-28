#!/usr/bin/env python3
"""Read-only runtime check for two dedicated customer Compose deployments."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from typing import Any


SERVICES = ("api", "mongodb", "meilisearch", "vectordb", "rag_api")
PRIVATE_SERVICES = ("mongodb", "meilisearch", "vectordb")
INTERNAL_SERVICES = ("mongodb", "meilisearch", "vectordb", "rag_api")
DATA_MOUNTS = {
    "api": ("/app/data", "/app/uploads"),
    "mongodb": ("/data/db",),
    "meilisearch": ("/meili_data",),
    "vectordb": ("/var/lib/postgresql/data",),
}
PROJECT_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,62}$")


class IsolationCheckError(RuntimeError):
    pass


def run(command: list[str]) -> str:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "command failed"
        raise IsolationCheckError(f"{command[0]} failed: {message}")
    return result.stdout.strip()


def inspect_container(name: str) -> dict[str, Any]:
    try:
        return json.loads(run(["docker", "inspect", name]))[0]
    except (IndexError, json.JSONDecodeError) as error:
        raise IsolationCheckError(f"Could not inspect container {name}") from error


def resolve_from(container: str, hostname: str, *, must_resolve: bool) -> None:
    code = (
        "require('dns').lookup(process.argv[1], (error) => {"
        "if (process.env.MUST_RESOLVE === 'true') {"
        "if (error) { console.error('expected service DNS name did not resolve'); process.exit(1); }"
        "console.log('resolved'); process.exit(0); }"
        "if (error) { console.log('blocked'); process.exit(0); }"
        "console.error('cross-project container unexpectedly resolved'); process.exit(1); });"
    )
    command = ["docker", "exec"]
    if must_resolve:
        command.extend(["-e", "MUST_RESOLVE=true"])
    command.extend([container, "node", "-e", code, hostname])
    run(command)


def probe_tcp_from(container: str, host: str, port: int) -> None:
    """Require a known private Mongo IP to be unreachable from another project."""
    code = (
        "const net=require('net');"
        "const socket=net.createConnection({host:process.env.PROBE_HOST,"
        "port:Number(process.env.PROBE_PORT),timeout:2000});"
        "let finished=false;"
        "function finish(message,status){if(finished)return;finished=true;"
        "console.log(message);socket.destroy();process.exit(status);};"
        "socket.once('connect',()=>{console.error('protected TCP port was reachable');"
        "finish('reachable',1);});"
        "socket.once('timeout',()=>finish('blocked',0));"
        "socket.once('error',(error)=>{"
        "if(['ENETUNREACH','EHOSTUNREACH','ETIMEDOUT'].includes(error.code))"
        "finish('blocked',0);"
        "else{console.error('unexpected TCP probe result: '+(error.code||'unknown'));"
        "finish('unexpected',1);}});"
    )
    run(
        [
            "docker",
            "exec",
            "-e",
            f"PROBE_HOST={host}",
            "-e",
            f"PROBE_PORT={port}",
            container,
            "node",
            "-e",
            code,
        ]
    )


def published_bindings(container: dict[str, Any]) -> list[str]:
    bindings = container.get("HostConfig", {}).get("PortBindings") or {}
    return [
        f"{port} -> {binding.get('HostIp', '*')}:{binding.get('HostPort')}"
        for port, entries in bindings.items()
        for binding in (entries or [])
        if binding.get("HostPort")
    ]


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Verify two running dedicated customer Compose projects have distinct "
            "networks and persistent storage. This does not modify containers or data."
        )
    )
    parser.add_argument("project_a", help="Compose project name for deployment A")
    parser.add_argument("project_b", help="Compose project name for deployment B")
    args = parser.parse_args()

    projects = (args.project_a, args.project_b)
    if any(not PROJECT_RE.fullmatch(project) for project in projects):
        raise IsolationCheckError("Project names must contain only lowercase letters, digits, _ or -")
    if projects[0] == projects[1]:
        raise IsolationCheckError("Two different Compose project names are required")

    inspected: dict[str, dict[str, dict[str, Any]]] = {}
    network_sets: dict[str, set[str]] = {}
    for project in projects:
        inspected[project] = {}
        for service in SERVICES:
            name = f"{project}-{service}-1"
            container = inspect_container(name)
            if not container.get("State", {}).get("Running"):
                raise IsolationCheckError(f"Required container is not running: {name}")
            inspected[project][service] = container

            networks = set(container.get("NetworkSettings", {}).get("Networks", {}))
            network_sets.setdefault(project, set()).update(networks)
            if not networks:
                raise IsolationCheckError(f"Container has no attached networks: {name}")

        private_name = f"{project}_private"
        private = json.loads(run(["docker", "network", "inspect", private_name]))[0]
        if private.get("Internal") is not True:
            raise IsolationCheckError(f"Private network is not marked internal: {private_name}")

        for service in PRIVATE_SERVICES:
            name = f"{project}-{service}-1"
            networks = inspected[project][service].get("NetworkSettings", {}).get("Networks", {})
            if private_name not in networks:
                raise IsolationCheckError(f"{name} is not attached to {private_name}")

        for service in INTERNAL_SERVICES:
            name = f"{project}-{service}-1"
            bindings = published_bindings(inspected[project][service])
            if bindings:
                raise IsolationCheckError(
                    f"Internal service {name} publishes host ports: {', '.join(bindings)}"
                )

        api_name = f"{project}-api-1"
        resolve_from(api_name, "mongodb", must_resolve=True)

    shared_networks = network_sets[projects[0]] & network_sets[projects[1]]
    if shared_networks:
        raise IsolationCheckError(
            "Deployments share Docker networks: " + ", ".join(sorted(shared_networks))
        )

    for source_project, target_project in ((projects[0], projects[1]), (projects[1], projects[0])):
        source_api = f"{source_project}-api-1"
        target_mongo = inspected[target_project]["mongodb"].get("Name", "").lstrip("/")
        if not target_mongo:
            raise IsolationCheckError(f"Could not determine target Mongo container for {target_project}")
        resolve_from(source_api, target_mongo, must_resolve=False)
        private_name = f"{target_project}_private"
        target_networks = inspected[target_project]["mongodb"].get("NetworkSettings", {}).get("Networks", {})
        target_network = target_networks.get(private_name)
        target_ip = target_network.get("IPAddress") if target_network else None
        if not target_ip:
            raise IsolationCheckError(f"Could not determine private Mongo IP for {target_project}")
        probe_tcp_from(source_api, target_ip, 27017)

    storage_sources: dict[str, dict[str, str]] = {}
    for project in projects:
        storage_sources[project] = {}
        for service, targets in DATA_MOUNTS.items():
            container = inspected[project][service]
            mounts = {mount.get("Destination"): mount.get("Source") for mount in container.get("Mounts", [])}
            for target in targets:
                source = mounts.get(target)
                if not source:
                    raise IsolationCheckError(f"Missing persistent mount {target} on {project}-{service}-1")
                storage_sources[project][target] = source

    for target in DATA_MOUNTS["api"] + DATA_MOUNTS["mongodb"] + DATA_MOUNTS["meilisearch"] + DATA_MOUNTS["vectordb"]:
        if storage_sources[projects[0]][target] == storage_sources[projects[1]][target]:
            raise IsolationCheckError(f"Deployments share a persistent storage source for {target}")

    print("Isolation check passed (read-only).")
    print(f"Projects: {projects[0]} / {projects[1]}")
    print(f"Networks are disjoint: {', '.join(sorted(network_sets[projects[0]]))} / {', '.join(sorted(network_sets[projects[1]]))}")
    print("Own Mongo service DNS resolves; cross-project Mongo container DNS is blocked both ways.")
    print("Cross-project TCP access to the known private Mongo IP is blocked both ways.")
    print("MongoDB, Meilisearch, pgvector, and RAG publish no host ports.")
    print("App data, uploads, MongoDB, Meilisearch, and pgvector storage roots are distinct.")
    print("This does not test member authentication/ACL behavior, provider billing, or VPS exposure.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except IsolationCheckError as error:
        print(f"Isolation check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
