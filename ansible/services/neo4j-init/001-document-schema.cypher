// Document and File storage schema for OpenWebUI integration
// This schema supports document storage, chunking, and retrieval for RAG applications

// ============================================
// CONSTRAINTS (Primary Keys)
// ============================================

// Documents - main file/document entities
CREATE CONSTRAINT document_id_unique IF NOT EXISTS FOR (d:Document) REQUIRE d.id IS UNIQUE;

// Text chunks from documents
CREATE CONSTRAINT chunk_id_unique IF NOT EXISTS FOR (c:Chunk) REQUIRE c.id IS UNIQUE;

// Users who upload/own documents  
CREATE CONSTRAINT user_id_unique IF NOT EXISTS FOR (u:User) REQUIRE u.id IS UNIQUE;

// Collections/folders for organizing documents
CREATE CONSTRAINT collection_id_unique IF NOT EXISTS FOR (col:Collection) REQUIRE col.id IS UNIQUE;

// ============================================
// INDEXES for Performance
// ============================================

// Document indexes
CREATE INDEX document_title_idx IF NOT EXISTS FOR (d:Document) ON (d.title);
CREATE INDEX document_filename_idx IF NOT EXISTS FOR (d:Document) ON (d.filename);
CREATE INDEX document_content_type_idx IF NOT EXISTS FOR (d:Document) ON (d.content_type);
CREATE INDEX document_created_idx IF NOT EXISTS FOR (d:Document) ON (d.created_at);
CREATE INDEX document_updated_idx IF NOT EXISTS FOR (d:Document) ON (d.updated_at);
CREATE INDEX document_size_idx IF NOT EXISTS FOR (d:Document) ON (d.size_bytes);

// Chunk indexes for fast retrieval
CREATE INDEX chunk_document_idx IF NOT EXISTS FOR (c:Chunk) ON (c.document_id);
CREATE INDEX chunk_position_idx IF NOT EXISTS FOR (c:Chunk) ON (c.position);
CREATE INDEX chunk_content_idx IF NOT EXISTS FOR (c:Chunk) ON (c.content);

// User indexes
CREATE INDEX user_email_idx IF NOT EXISTS FOR (u:User) ON (u.email);
CREATE INDEX user_created_idx IF NOT EXISTS FOR (u:User) ON (u.created_at);

// Collection indexes
CREATE INDEX collection_name_idx IF NOT EXISTS FOR (col:Collection) ON (col.name);
CREATE INDEX collection_created_idx IF NOT EXISTS FOR (col:Collection) ON (col.created_at);

// ============================================
// SAMPLE DATA STRUCTURE
// ============================================

// Create schema documentation node
MERGE (schema:Schema {name: "OpenWebUI_FileStore"})
SET schema.description = "File and document storage schema for OpenWebUI RAG system",
    schema.version = "2.0",
    schema.created_at = datetime(),
    schema.supports = [
        "Document upload and storage",
        "Text chunking for RAG",
        "User-based file ownership", 
        "Collections/folders",
        "Full-text search",
        "Metadata storage"
    ];

// Create default collection
MERGE (defaultCol:Collection {id: "default", name: "Default"})
SET defaultCol.description = "Default collection for uncategorized documents",
    defaultCol.created_at = datetime();

// ============================================
// SAMPLE QUERIES (commented for reference)
// ============================================

// Example: Create a document with chunks
// MERGE (doc:Document {
//     id: "doc_123",
//     title: "Sample Document", 
//     filename: "sample.pdf",
//     content_type: "application/pdf",
//     size_bytes: 1024000,
//     created_at: datetime(),
//     updated_at: datetime()
// })
// MERGE (user:User {id: "user_456", email: "user@example.com"})
// MERGE (collection:Collection {id: "col_789", name: "Research Papers"})
// MERGE (user)-[:OWNS]->(doc)
// MERGE (doc)-[:IN_COLLECTION]->(collection)

// Example: Create text chunks
// MERGE (chunk1:Chunk {
//     id: "chunk_1", 
//     document_id: "doc_123",
//     content: "This is the first chunk of text...",
//     position: 0,
//     start_char: 0,
//     end_char: 100
// })
// MERGE (doc)-[:HAS_CHUNK]->(chunk1)

// Example: Search chunks by content
// MATCH (c:Chunk) WHERE c.content CONTAINS "search term" RETURN c

// Example: Get all chunks for a document in order
// MATCH (d:Document {id: "doc_123"})-[:HAS_CHUNK]->(c:Chunk) 
// RETURN c ORDER BY c.position
