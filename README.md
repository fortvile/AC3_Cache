# Controlador de Cache RISC-V

## Descrição do Projeto
Este projeto implementa um controlador de cache de mapeamento direto (Direct-Mapped Cache) com políticas de escrita Write-Back e Write-Allocate, seguindo as especificações do livro *Computer Organization and Design (RISC-V Edition)*. O sistema gerencia a interação entre CPU e Memória Principal, tratando hits, misses e conflitos de dados.

## Dependências
- [Icarus Verilog](http://iverilog.icarus.com/): Para compilação e simulação.
- [GTKWave](http://gtkwave.sourceforge.net/): Opcional, para visualização das formas de onda (waveforms).

## Compilação
iverilog -g2012 -o cache_sim cache_def.sv cache_controller.sv cache_tb.sv

## Execução
vvp cache_sim

## Visualização
gtkwave cache_waveform.vcd
