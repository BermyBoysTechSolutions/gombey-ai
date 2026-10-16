const fs = require('fs');
const axios = require('axios');
const FormData = require('form-data');
const { logger } = require('@librechat/data-schemas');
const { FileContext, FileSources } = require('librechat-data-provider');
const { logAxiosError, generateShortLivedToken } = require('@librechat/api');

/**
 * Delete vector chunks for a file. Agent File Search vectors are stored in the
 * RAG service under each entity in file.metadata.embeddedEntities, not only
 * under the uploading user's ID. Pass each recorded entity scope so the RAG
 * service can authorize and remove the correct chunks.
 */
const deleteVectors = async (req, file) => {
  if (!file.embedded || !process.env.RAG_API_URL) {
    return;
  }

  try {
    const jwtToken = generateShortLivedToken(req.user.id);
    const entityIds = Array.isArray(file.metadata?.embeddedEntities)
      ? [...new Set(file.metadata.embeddedEntities.filter(Boolean))]
      : [];
    if (file.context === FileContext.agents && entityIds.length === 0) {
      throw new Error('Shared-agent File Search record is missing its vector entity scope');
    }
    const scopes = entityIds.length > 0 ? entityIds : [undefined];

    for (const entityId of scopes) {
      try {
        await axios.delete(`${process.env.RAG_API_URL}/documents`, {
          ...(entityId ? { params: { entity_id: entityId } } : {}),
          headers: {
            Authorization: `Bearer ${jwtToken}`,
            'Content-Type': 'application/json',
            accept: 'application/json',
          },
          data: [file.file_id],
        });
      } catch (error) {
        // A stale or already-removed association is harmless; keep trying any
        // remaining recorded scopes, but fail on actual service errors.
        if (error.response?.status !== 404) {
          throw error;
        }
      }
    }
  } catch (error) {
    logAxiosError({
      error,
      message: 'Error deleting vectors',
    });
    logger.warn('Error deleting vectors; retaining the file record so deletion can be retried');
    throw new Error(error.message || 'An error occurred during file deletion.');
  }
};

/**
 * Uploads a file to the configured Vector database
 *
 * @param {Object} params - The params object.
 * @param {Object} params.req - The request object with an authenticated user.
 * @param {Express.Multer.File} params.file - The uploaded file.
 * @param {string} params.file_id - The file ID.
 * @param {string} [params.entity_id] - The shared agent entity ID.
 * @param {Object} [params.storageMetadata] - Storage metadata for dual storage.
 * @returns {Promise<{ filepath: string, bytes: number }>}
 */
async function uploadVectors({ req, file, file_id, entity_id, storageMetadata, signal }) {
  if (!process.env.RAG_API_URL) {
    throw new Error('RAG_API_URL not defined');
  }

  try {
    const jwtToken = generateShortLivedToken(req.user.id);
    const formData = new FormData();
    formData.append('file_id', file_id);
    formData.append('file', fs.createReadStream(file.path));
    if (entity_id != null && entity_id) {
      formData.append('entity_id', entity_id);
    }

    if (storageMetadata) {
      formData.append('storage_metadata', JSON.stringify(storageMetadata));
    }

    const formHeaders = formData.getHeaders();
    const response = await axios.post(`${process.env.RAG_API_URL}/embed`, formData, {
      ...(signal ? { signal } : {}),
      headers: {
        Authorization: `Bearer ${jwtToken}`,
        accept: 'application/json',
        ...formHeaders,
      },
    });

    const responseData = response.data;
    logger.debug('Response from embedding file', responseData);

    if (responseData.known_type === false) {
      throw new Error(`File embedding failed. The filetype ${file.mimetype} is not supported`);
    }
    if (!responseData.status) {
      throw new Error('File embedding failed.');
    }

    return {
      bytes: file.size,
      filename: file.originalname,
      filepath: FileSources.vectordb,
      embedded: Boolean(responseData.known_type),
    };
  } catch (error) {
    logAxiosError({
      error,
      message: 'Error uploading vectors',
    });
    throw new Error(error.message || 'An error occurred during file upload.');
  }
}

module.exports = {
  deleteVectors,
  uploadVectors,
};
