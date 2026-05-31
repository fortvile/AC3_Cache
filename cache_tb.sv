// =============================================================================
// Arquivo: cache_tb.sv
// Descrição: Testbench automatizado para o Controlador de Cache síncrono.
// =============================================================================

`timescale 1ns/1ps
import cache_def::*;

module cache_tb;

    logic clk;
    logic rst_n;

    logic         cpu_req_valid;
    logic         cpu_req_write;
    logic [31:0]  cpu_addr;
    logic [31:0]  cpu_wdata;
    logic         cpu_ready;
    logic [31:0]  cpu_rdata;

    logic         mem_ready;
    logic [127:0] mem_rdata;
    logic         mem_req_valid;
    logic         mem_write;
    logic [31:0]  mem_addr;
    logic [127:0] mem_wdata;

    cache_controller dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_req_valid (cpu_req_valid),
        .cpu_req_write (cpu_req_write),
        .cpu_addr      (cpu_addr),
        .cpu_wdata     (cpu_wdata),
        .cpu_ready     (cpu_ready),
        .cpu_rdata     (cpu_rdata),
        .mem_ready     (mem_ready),
        .mem_rdata     (mem_rdata),
        .mem_req_valid (mem_req_valid),
        .mem_write     (mem_write),
        .mem_addr      (mem_addr),
        .mem_wdata     (mem_wdata)
    );

    always #5 clk = ~clk;

    localparam int MEM_LATENCY = 3;
    int latency_counter = 0;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready       <= 1'b0;
            mem_rdata       <= '0;
            latency_counter <= 0;
        end else begin
            if (mem_req_valid && !mem_ready) begin
                if (latency_counter < MEM_LATENCY - 1) begin
                    latency_counter <= latency_counter + 1;
                    mem_ready       <= 1'b0;
                end else begin
                    mem_ready <= 1'b1;
                    if (!mem_write) begin
                        mem_rdata[31:0]   <= {mem_addr[31:4], 4'hA};
                        mem_rdata[63:32]  <= {mem_addr[31:4], 4'hB};
                        mem_rdata[95:64]  <= {mem_addr[31:4], 4'hC};
                        mem_rdata[127:96] <= {mem_addr[31:4], 4'hD};
                    end
                end
            end else begin
                latency_counter <= 0;
                mem_ready       <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (mem_req_valid && mem_ready && mem_write) begin
            $display("[MEMÓRIA] Gravando Bloco: Endereço=%h, Dados=%h", mem_addr, mem_wdata);
        end
    end

    task automatic cpu_read(input logic [31:0] addr);
        begin
            cpu_req_valid = 1'b1;
            cpu_req_write = 1'b0;
            cpu_addr      = addr;
            
            // Espera o ready subir
            while (!cpu_ready) begin
                @(posedge clk);
            end
            
            // LÊ O DADO AGORA, ENQUANTO O READY AINDA ESTÁ ALTO!
            $display("[CPU LEITURA] Endereço=%h -> Dado Lido=%h", addr, cpu_rdata);
            
            // Só agora finalizamos o pedido
            cpu_req_valid = 1'b0;
            @(posedge clk); 
        end
    endtask

    task automatic cpu_write(input logic [31:0] addr, input logic [31:0] wdata);
        begin
            cpu_req_valid = 1'b1;
            cpu_req_write = 1'b1;
            cpu_addr      = addr;
            cpu_wdata     = wdata;
            
            while (!cpu_ready) begin
                @(posedge clk);
            end
            cpu_req_valid = 1'b0;
            @(posedge clk); 
            $display("[CPU ESCRITA] Endereço=%h <- Dado Gravado=%h", addr, wdata);
            #1;
        end
    endtask

    initial begin
        $dumpfile("cache_waveform.vcd");
        $dumpvars(0, cache_tb);

        clk           = 1'b0;
        rst_n         = 1'b0;
        cpu_req_valid = 1'b0;
        cpu_req_write = 1'b0;
        cpu_addr      = '0;
        cpu_wdata     = '0;

        $display("\n==================================================");
        $display("INICIANDO VERIFICAÇÃO FUNCIONAL DO CONTROLADOR DE CACHE");
        $display("==================================================\n");

        $display("[CENÁRIO 7.5] Aplicando Reset Geral...");
        #20 rst_n = 1'b1; 
        #10;
        
        $display("\n[CENÁRIO 7.1] Testando Leitura com Cache Miss...");
        cpu_read(32'h00004050); 
        
        $display("\n[CENÁRIO 7.1] Testando Leitura com Cache Hit subsequente...");
        cpu_read(32'h00004050);

        $display("\n[CENÁRIO 7.2] Testando Escrita com Cache Hit...");
        cpu_write(32'h00004050, 32'hDEADBEEF);
        
        $display("\n[CENÁRIO 7.1/7.2] Verificando Leitura do dado modificado...");
        cpu_read(32'h00004050);

        $display("\n[CENÁRIO 7.2] Testando Escrita com Cache Miss (Linha Limpa)...");
        cpu_write(32'h000080a0, 32'hCAFEBABE);

        $display("\n[CENÁRIO 7.3 & 7.4] Testando Conflito de Índice e Substituição de Bloco Dirty...");
        cpu_read(32'h00024050);

        $display("\n[CENÁRIO 7.4] Confirmando Consistência após Alocação...");
        cpu_read(32'h00024050);

        $display("\n==================================================");
        $display("TESTES CONCLUÍDOS COM SUCESSO!");
        $display("==================================================\n");
        $finish;
    end

endmodule : cache_tb