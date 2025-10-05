// Document storage schema for OpenWebUI integration
// Create indexes for document retrieval and search

// Create constraints and indexes for Document nodes
CREATE CONSTRAINT document_id IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE;
CREATE INDEX document_title_idx IF NOT EXISTS FOR (d:Document) ON (d.title);
CREATE INDEX document_type_idx IF NOT EXISTS FOR (d:Document) ON (d.type);
CREATE INDEX document_created_idx IF NOT EXISTS FOR (d:Document) ON (d.created_at);

// Create indexes for Text chunks
CREATE CONSTRAINT chunk_id IF NOT EXISTS FOR (c:Chunk) REQUIRE c.id IS UNIQUE;
CREATE INDEX chunk_document_idx IF NOT EXISTS FOR (c:Chunk) ON (c.document_id);

// Create indexes for Vector embeddings (if using vector search)
CREATE INDEX vector_embedding_idx IF NOT EXISTS FOR (v:Vector) ON (v.embedding);

// Create sample schema for document relationships
// Documents can have chunks, metadata, and relationships to other documents
MERGE (schema:Schema {name: "DocumentStore"})
SET schema.description = "Schema for storing documents and their relationships",
    schema.version = "1.0",
    schema.created_at = datetime();
