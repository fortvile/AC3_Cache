// =============================================================================
// Arquivo: cache_controller.sv
// Descrição: Controlador de Cache Mapeada Direto com FSM síncrona.
//            Política: Write-Back com Write-Allocate.
// =============================================================================

import cache_def::*;

module cache_controller (
    // Interface com a CPU
    input  logic         clk,
    input  logic         rst_n,
    input  logic         cpu_req_valid,
    input  logic         cpu_req_write,
    input  logic [31:0]  cpu_addr,
    input  logic [31:0]  cpu_wdata,
    output logic         cpu_ready,
    output logic [31:0]  cpu_rdata,

    // Interface com a Memória Principal
    input  logic         mem_ready,
    input  logic [127:0] mem_rdata,
    output logic         mem_req_valid,
    output logic         mem_write,
    output logic [31:0]  mem_addr,
    output logic [127:0] mem_wdata
);

    // --- Definições Locais ---
    localparam int CACHE_LINES  = 1024;
    localparam int TAG_WIDTH    = 18;
    localparam int INDEX_WIDTH  = 10;

    typedef enum logic [1:0] {
        IDLE_COMPARE_TAG = 2'b00,
        WRITE_BACK       = 2'b01,
        ALLOCATE         = 2'b10
    } state_t;

    state_t current_state, next_state;

    // --- Memórias Internas ---
    logic                 tag_valid     [CACHE_LINES-1:0];
    logic                 tag_dirty     [CACHE_LINES-1:0];
    logic [TAG_WIDTH-1:0] tag_store     [CACHE_LINES-1:0];
    logic [31:0]          data_store_w0 [CACHE_LINES-1:0];
    logic [31:0]          data_store_w1 [CACHE_LINES-1:0];
    logic [31:0]          data_store_w2 [CACHE_LINES-1:0];
    logic [31:0]          data_store_w3 [CACHE_LINES-1:0];

    // --- Decodificação ---
    logic [TAG_WIDTH-1:0]   curr_addr_tag;
    logic [INDEX_WIDTH-1:0] curr_addr_index;
    logic [1:0]             word_offset;

    assign word_offset     = cpu_addr[3:2];
    assign curr_addr_index = cpu_addr[13:4];  
    assign curr_addr_tag   = cpu_addr[31:14]; 

    // --- Sinais de Controle ---
    logic [TAG_WIDTH-1:0] line_tag;
    logic                 line_valid;
    logic                 line_dirty;
    logic                 is_hit;

    assign line_valid  = tag_valid[curr_addr_index];
    assign line_dirty  = tag_dirty[curr_addr_index];
    assign line_tag    = tag_store[curr_addr_index];
    assign is_hit      = line_valid && (line_tag == curr_addr_tag);

    logic [31:0] w0, w1, w2, w3;
    assign w0 = data_store_w0[curr_addr_index];
    assign w1 = data_store_w1[curr_addr_index];
    assign w2 = data_store_w2[curr_addr_index];
    assign w3 = data_store_w3[curr_addr_index];

    logic [31:0] selected_word;
    assign selected_word = (word_offset == 2'b00) ? w0 :
                           (word_offset == 2'b01) ? w1 :
                           (word_offset == 2'b10) ? w2 : w3;

    // CORREÇÃO: Bypass Combinacional. cpu_rdata agora reflete o valor atual 
    // da cache instantaneamente, sem depender do registrador defasado.
    assign cpu_rdata = selected_word;

    // --- LÓGICA DE ESTADOS ---
    always_comb begin
        next_state    = current_state;
        cpu_ready     = 1'b0;
        mem_req_valid = 1'b0;
        mem_write     = 1'b0;
        mem_addr      = 32'b0;

        case (current_state)
            IDLE_COMPARE_TAG: begin
                if (cpu_req_valid) begin
                    if (is_hit) begin
                        cpu_ready = 1'b1;
                    end else if (line_valid && line_dirty) begin
                        next_state = WRITE_BACK;
                    end else begin
                        next_state = ALLOCATE;
                    end
                end
            end
            WRITE_BACK: begin
                mem_req_valid = 1'b1; mem_write = 1'b1;
                mem_addr      = {line_tag, curr_addr_index, 4'b0};
                if (mem_ready) next_state = ALLOCATE;
            end
            ALLOCATE: begin
                mem_req_valid = 1'b1; mem_write = 1'b0;
                mem_addr      = {curr_addr_tag, curr_addr_index, 4'b0};
                if (mem_ready) next_state = IDLE_COMPARE_TAG;
            end
        endcase
    end

    // --- BLOCO SEQUENCIAL ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE_COMPARE_TAG;
            mem_wdata     <= '0;
            for (int i = 0; i < CACHE_LINES; i++) begin
                tag_valid[i] <= 0; tag_dirty[i] <= 0;
            end
        end else begin
            current_state <= next_state;

            // Escrita no Hit
            if (cpu_req_valid && cpu_req_write && (current_state == IDLE_COMPARE_TAG) && is_hit) begin
                tag_dirty[curr_addr_index] <= 1'b1;
                case (word_offset)
                    2'b00: data_store_w0[curr_addr_index] <= cpu_wdata;
                    2'b01: data_store_w1[curr_addr_index] <= cpu_wdata;
                    2'b10: data_store_w2[curr_addr_index] <= cpu_wdata;
                    2'b11: data_store_w3[curr_addr_index] <= cpu_wdata;
                endcase
            end
            
            // Write-Back
            if (current_state == IDLE_COMPARE_TAG && cpu_req_valid && !is_hit && line_valid && line_dirty)
                mem_wdata <= {w3, w2, w1, w0};
            
            // Alocação (Miss)
            if (current_state == ALLOCATE && mem_ready) begin
                tag_valid[curr_addr_index] <= 1'b1;
                tag_store[curr_addr_index] <= curr_addr_tag;
                tag_dirty[curr_addr_index] <= cpu_req_write;
                data_store_w0[curr_addr_index] <= (word_offset == 2'b00 && cpu_req_write) ? cpu_wdata : mem_rdata[31:0];
                data_store_w1[curr_addr_index] <= (word_offset == 2'b01 && cpu_req_write) ? cpu_wdata : mem_rdata[63:32];
                data_store_w2[curr_addr_index] <= (word_offset == 2'b10 && cpu_req_write) ? cpu_wdata : mem_rdata[95:64];
                data_store_w3[curr_addr_index] <= (word_offset == 2'b11 && cpu_req_write) ? cpu_wdata : mem_rdata[127:96];
            end
        end
    end
endmodule : cache_controller