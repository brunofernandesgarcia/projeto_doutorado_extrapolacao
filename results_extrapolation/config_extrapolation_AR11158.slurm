#!/bin/bash

#SBATCH --job-name=NF2_Extrapolacao_teste_1_SCRATCH
#SBATCH --output=extrapolacao_teste_1_output_%j.out
#SBATCH --error=extrapolacao_teste_1_error_%j.err
#SBATCH --partition=pgpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --gpus=1


# --- CONFIGURAÇÃO DE SEGURANÇA ---
# Adicionado: O script irá parar imediatamente se qualquer comando falhar.
set -e

echo "=========================================================="
echo "Iniciando o trabalho de extrapolação NF2 - OTIMIZADO COM SCRATCH (v2)"
echo "Job ID: $SLURM_JOB_ID"
echo "Nó: $SLURMD_NODENAME"
echo "=========================================================="

# --- ADICIONA ESTA LINHA ---
# Define a variável de ambiente para desativar o wandb
export WANDB_MODE=disabled

# --- ETAPA 1: DEFINIÇÃO DE VARIÁVEIS ---
# Todos os caminhos importantes são definidos aqui para fácil edição.
DATA_ROOT_ON_HOME="/home/bruno.garcia/bruno.garcia/projeto_doutorado/2025/NF2_Bruno/results_extrapolation/data/AR_11158"
CONFIG_SOURCE_PATH="/home/bruno.garcia/bruno.garcia/projeto_doutorado/2025/NF2_Bruno/config_yaml/sharp/config_extrapolation.yaml"
SCRATCH_DIR="/scratchin/users/$USER/$SLURM_JOB_ID"
TEMP_CONFIG_PATH="${SCRATCH_DIR}/config_extrapolation_temp.yaml"

# --- ETAPA 2: PREPARAÇÃO DO DIRETÓRIO DE TRABALHO RÁPIDO ---
echo "--> Criando diretório de trabalho temporário..."
mkdir -p $SCRATCH_DIR
echo "--- Verificando o diretório criado: ---"
ls -ld $SCRATCH_DIR
echo "------------------------------------"

# --- ETAPA 3: CÓPIA DOS DADOS PARA O SCRATCH ---
echo "--> Copiando arquivos .fits para o diretório de trabalho rápido..."
cp "${DATA_ROOT_ON_HOME}"/*.fits ${SCRATCH_DIR}/

echo "--- Verificando arquivos copiados: ---"
ls -lh ${SCRATCH_DIR}/*.fits
echo "------------------------------------"

# --- ETAPA 4: MODIFICAÇÃO DO ARQUIVO DE CONFIGURAÇÃO ---
echo "--> Copiando e modificando o arquivo de configuração..."
cp $CONFIG_SOURCE_PATH $TEMP_CONFIG_PATH
sed -i "s|${DATA_ROOT_ON_HOME}|${SCRATCH_DIR}|g" $TEMP_CONFIG_PATH
echo "--- Verificando o arquivo de config temporário: ---"
ls -l $TEMP_CONFIG_PATH
echo "--- Conteúdo do 'sed' (primeiras 15 linhas): ---"
head -n 15 $TEMP_CONFIG_PATH
echo "------------------------------------"

# --- ETAPA 5: EXECUÇÃO DO TREINO ---
echo "--> Iniciando a execução do script Python..."
# Carregar módulos e configurar ambiente
module load miniconda3
module load cuda/12.6
source activate gpu311

# --- INÍCIO DO BLOCO DE DIAGNÓSTICO ---
echo "=========================================================="
echo "INICIANDO DIAGNÓSTICO DO AMBIENTE"
echo "Nó de execução: $(hostname)"
echo "Variável CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
echo "----------------------------------------------------------"
echo "Executando teste mínimo com Python para ver GPUs:"

python -c "import torch; print(f'Versão do PyTorch: {torch.__version__}'); print(f'CUDA disponível? {torch.cuda.is_available()}'); print(f'Número de GPUs detectadas: {torch.cuda.device_count()}')"

echo "----------------------------------------------------------"
echo "Verificando o estado do NVIDIA-SMI no nó:"
nvidia-smi
echo "=========================================================="
# --- FIM DO BLOCO DE DIAGNÓSTICO ---

export TORCH_DISTRIBUTED_DEBUG=DETAIL
export CUDA_VISIBLE_DEVICES="0,1,2,3"

echo "--> Iniciando a execução do script Python..."
srun python -u bruno.garcia/projeto_doutorado/2025/NF2_Bruno/nf2/extrapolate.py --config $TEMP_CONFIG_PATH 
echo "Execução do Python finalizada."

# --- ETAPA 6: LIMPEZA ---
echo "--> Limpando o diretório de trabalho temporário..."
rm -rf $SCRATCH_DIR
echo "Limpeza concluída."

echo "=========================================================="
echo "Trabalho finalizado."
echo "=========================================================="