// =============================================================================
// Arquivo: cache_def.sv
// Descrição: Pacote de definições de tipos e estruturas de dados para o
//            Controlador de Cache (Mapeamento Direto, 16 KiB, Bloco de 128 bits)
//            Baseado na especificação do Capítulo 5 do livro Patterson & Hennessy.
// =============================================================================

package cache_def;

    // Tamanho do endereço de memória (RISC-V de 32 bits)
    localparam int ADDR_WIDTH = 32;

    // Configuração da Cache: 16 KiB total / 16 Bytes (128 bits) por bloco = 1024 linhas
    localparam int CACHE_LINES = 1024; 
    
    // Decomposição do Endereço de 32 bits:
    // [31:14] -> Tag (18 bits)
    // [13:4]  -> Index (10 bits, pois 2^10 = 1024 linhas)
    // [3:0]   -> Byte Offset (4 bits, pois 2^4 = 16 bytes por bloco)
    localparam int TAG_WIDTH    = 18;
    localparam int INDEX_WIDTH  = 10;
    localparam int OFFSET_WIDTH = 4;

    // Largura do bloco de dados (4 palavras de 32 bits = 128 bits)
    localparam int BLOCK_WIDTH  = 128;
    localparam int WORD_WIDTH   = 32;

    // Tipo para armazenamento e barramento de dados do bloco da cache
    typedef logic [BLOCK_WIDTH-1:0] cache_data_type;

    // Estrutura empacotada (packed) para os metadados da Tag de controle
    typedef struct packed {
        logic                   valid;       // 1 bit: Indica se a linha é válida
        logic                   dirty;       // 1 bit: Indica se o bloco foi modificado (Write-Back)
        logic [TAG_WIDTH-1:0]   tag;         // 18 bits: Identificador do bloco na memória
    } cache_tag_type;

    // Estrutura auxiliar para desmembramento explícito do endereço de 32 bits
    typedef struct packed {
        logic [TAG_WIDTH-1:0]   tag;         // [31:14]
        logic [INDEX_WIDTH-1:0] index;       // [13:4]
        logic [OFFSET_WIDTH-1:0] offset;     // [3:0]
    } riscv_addr_type;

endpackage : cache_def