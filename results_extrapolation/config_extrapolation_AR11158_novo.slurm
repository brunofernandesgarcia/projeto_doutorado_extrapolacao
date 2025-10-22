#!/bin/bash

# --- Configurações do SLURM (Corrigidas conforme o manual) ---
#SBATCH --job-name=NF2_Extrapolacao_teste_1_SCRATCH
#SBATCH --output=extrapolacao_teste_1_output_%j.out
#SBATCH --error=extrapolacao_teste_1_error_%j.err
#SBATCH --partition=pgpu                 # Correto, usa a partição 'pgpu' [cite: 39]
#SBATCH --gres=gpu:A100:1                # <-- MUDANÇA: Método recomendado pelo manual para pedir 1 GPU A100 
#SBATCH --cpus-per-gpu=12                # <-- MUDANÇA: Método recomendado para alocar CPUs para a GPU [cite: 40, 43]

# --- CONFIGURAÇÃO DE SEGURANÇA ---
set -e

echo "=========================================================="
echo "Iniciando o trabalho de extrapolação NF2 - OTIMIZADO COM SCRATCH (v2)"
echo "Job ID: $SLURM_JOB_ID"
echo "Nó: $SLURMD_NODENAME"
echo "GPU Alocada (info do SLURM): $CUDA_VISIBLE_DEVICES" # Mostra a GPU que o SLURM te deu
echo "=========================================================="

unset DISPLAY
echo "--> Variável DISPLAY removida para forçar modo não-interativo."

# --- Desativar o wandb ---
export WANDB_MODE=offline
echo "--> WANDB_MODE configurado para: $WANDB_MODE"
export MPLBACKEND=Agg
echo "--> MPLBACKEND configurado para: $MPLBACKEND (modo não-interativo)"

# --- ETAPA 1: DEFINIÇÃO DE VARIÁVEIS ---
DATA_ROOT_ON_HOME="/home/bruno.garcia/bruno.garcia/projeto_doutorado/2025/NF2_Bruno/results_extrapolation/data/AR_11158"
CONFIG_SOURCE_PATH="/home/bruno.garcia/bruno.garcia/projeto_doutorado/2025/NF2_Bruno/config_yaml/sharp/config_extrapolation.yaml"
SCRATCH_DIR="/scratchin/users/$USER/$SLURM_JOB_ID"
TEMP_CONFIG_PATH="${SCRATCH_DIR}/config_extrapolation_temp.yaml"
# <-- MUDANÇA: Caminho absoluto para o script python
PYTHON_SCRIPT_PATH="/home/bruno.garcia/bruno.garcia/projeto_doutorado/2025/NF2_Bruno/nf2/extrapolate.py"
WANDB_SAVE_DIR="$HOME/wandb_offline_runs/$SLURM_JOB_ID" # --- ADIÇÃO: Definir onde guardar os logs wandb persistentemente ---


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
echo "------------------------------------"

# --- ETAPA 5: EXECUÇÃO DO TREINO ---
echo "--> Carregando módulos e ativando ambiente..."
module load miniconda3  # 
module load cuda/12.6    # [cite: 30]
source activate gpu311   #  (assumindo que 'gpu311' é o nome do teu ambiente)

# --- INÍCIO DO BLOCO DE DIAGNÓSTICO ---
echo "=========================================================="
echo "INICIANDO DIAGNÓSTICO DO AMBIENTE"
echo "Nó de execução: $(hostname)"
echo "Ambiente Conda ativo: $CONDA_DEFAULT_ENV"
echo "Variável CUDA_VISIBLE_DEVICES (definida pelo SLURM): $CUDA_VISIBLE_DEVICES"
echo "----------------------------------------------------------"
echo "Executando teste mínimo com Python para ver GPUs:"
python -c "import torch; print(f'Versão do PyTorch: {torch.__version__}'); print(f'CUDA disponível? {torch.cuda.is_available()}'); print(f'Número de GPUs detectadas: {torch.cuda.device_count()}')"
echo "----------------------------------------------------------"
echo "Verificando o estado do NVIDIA-SMI no nó:"
nvidia-smi
echo "=========================================================="
# --- FIM DO BLOCO DE DIAGNÓSTICO ---

export TORCH_DISTRIBUTED_DEBUG=DETAIL
# export CUDA_VISIBLE_DEVICES="0,1,2,3" # <-- MUDANÇA: REMOVIDA! O SLURM trata disto.

echo "--> Iniciando a execução do script Python..."
# Usamos -u para que a saída do Python não fique presa no buffer
srun python -u $PYTHON_SCRIPT_PATH --config $TEMP_CONFIG_PATH --offline
echo "Execução do Python finalizada."

echo "--> Copiando logs offline do wandb para $WANDB_SAVE_DIR..."
# O wandb cria um diretório 'wandb' dentro do diretório de trabalho do script.
# Precisamos descobrir onde o script realmente guarda isso.
# Assumindo que o WandbLogger usa o work_directory do YAML:
WANDB_LOG_PATH_IN_SCRATCH="${SCRATCH_DIR}/wandb"
if [ -d "$WANDB_LOG_PATH_IN_SCRATCH" ]; then
  mkdir -p "$(dirname "$WANDB_SAVE_DIR")" # Cria o diretório pai, se necessário
  cp -r "$WANDB_LOG_PATH_IN_SCRATCH" "$WANDB_SAVE_DIR"
  echo "--- Logs do wandb copiados com sucesso. ---"
else
  echo "--- AVISO: Diretório $WANDB_LOG_PATH_IN_SCRATCH não encontrado. Logs do wandb não copiados. ---"
fi
# ------------------------------------------------------

# --- ETAPA 6: LIMPEZA ---
echo "--> Limpando o diretório de trabalho temporário..."
rm -rf $SCRATCH_DIR
echo "Limpeza concluída."

echo "=========================================================="
echo "Trabalho finalizado."
echo "=========================================================="