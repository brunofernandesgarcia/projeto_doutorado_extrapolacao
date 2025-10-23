# Guia Prático: Extrapolação de Múltiplas Alturas com NF2

Este guia explica como realizar a extrapolação do campo magnético solar utilizando dados de múltiplas alturas (fotosfera e cromosfera) com o código NF2, baseado no artigo de Jarolim et al. (2024a).

## Visão Geral

A extrapolação de múltiplas alturas aprimora os modelos do campo magnético coronal ao incorporar observações da cromosfera, que fornecem restrições mais realistas da estrutura 3D do campo magnético em comparação com o uso exclusivo de dados da fotosfera.

O processo consiste em:
1.  **Preparar os Dados:** Organizar os arquivos de dados da fotosfera e da cromosfera.
2.  **Criar um Arquivo de Configuração YAML:** Definir os caminhos dos dados, os parâmetros do modelo e as configurações de treinamento.
3.  **Executar a Extrapolação:** Utilizar o script `nf2-extrapolate` com o arquivo de configuração.

---

## Passo 1: Preparação dos Dados

Você precisará de, no mínimo, dois conjuntos de dados:

1.  **Magnetograma Vetorial da Fotosfera:** Geralmente obtido de instrumentos como o HMI (Helioseismic and Magnetic Imager) do SDO. Este será sua camada de base (`z=0`).
2.  **Magnetograma da Cromosfera:** Pode ser um magnetograma vetorial completo ou apenas a componente longitudinal (line-of-sight), obtido de instrumentos como o SOLIS/VSM (Vector Spectromagnetograph).

Os dados devem estar em um formato que o NF2 consiga ler, como arquivos FITS. É importante que os dados estejam co-alinhados espacialmente.

## Passo 2: Criação do Arquivo de Configuração YAML

Crie um novo arquivo `.yaml` (por exemplo, `minha_extrapolacao.yaml`). Este arquivo terá três seções principais: `base_path`, `data`, e `training`.

### 2.1. Configuração Base

Defina o caminho onde os resultados serão salvos.

```yaml
base_path: "/caminho/para/salvar/resultados/"
logging:
  project: "minha_extrapolacao"
  name: "teste_multi_altura"
```

### 2.2. Configuração dos Dados (`data`)

Esta é a seção mais importante para a extrapolação de múltiplas alturas. Você definirá as diferentes "fatias" (`slices`) de dados.

```yaml
data:
  type: fits # Ou o tipo de dado correspondente, como 'muram'
  slices:
    # Fatia 1: Fotosfera (condição de contorno inferior)
    - fits_path:
        Br: "/caminho/para/dados/photosphere.Br.fits"
        Bt: "/caminho/para/dados/photosphere.Bt.fits"
        Bp: "/caminho/para/dados/photosphere.Bp.fits"
      # Não é necessário 'height_mapping' para a camada base

    # Fatia 2: Cromosfera
    - fits_path:
        # Se você tiver o vetor completo:
        Br: "/caminho/para/dados/chromosphere.Br.fits"
        Bt: "/caminho/para/dados/chromosphere.Bt.fits"
        Bp: "/caminho/para/dados/chromosphere.Bp.fits"
        # Se tiver apenas a componente line-of-sight (Bz, neste caso):
        # Bz: "/caminho/para/dados/chromosphere.Bz.fits"
      height_mapping:
        z: 2.0      # Altura média estimada da observação em Mm
        z_min: 0.0  # Altura mínima para o mapeamento dinâmico
        z_max: 4.0  # Altura máxima para o mapeamento dinâmico

  num_workers: 8
  iterations: 10000
```

**Observações Importantes:**

-   A primeira fatia da lista é tratada como `boundary_01`, a segunda como `boundary_02`, e assim por diante.
-   O `height_mapping` é crucial para as camadas acima da fotosfera. O valor de `z` deve ser sua melhor estimativa da altura de formação da linha espectral usada para a observação.

### 2.3. Configuração do Treinamento (`training`)

Aqui, você instrui o modelo a usar as múltiplas camadas e a ativar o mapeamento de altura.

```yaml
model:
  type: vector_potential # Recomendado para garantir um campo livre de divergência
  dim: 256

training:
  epochs: 100
  loss_config:
    # Perda para as condições de contorno (todas as fatias)
    - type: boundary
      name: boundary
      lambda: 1.0
      ds_id: [boundary_01, boundary_02] # ID das suas fatias

    # Perda para o mapeamento de altura (apenas fatias cromosféricas)
    - type: height
      name: height
      lambda: 1.0e-3
      ds_id: [boundary_02] # ID da fatia cromosférica

    # Perdas físicas (force-free e divergence-free)
    - type: force_free
      lambda: 1.0e-1
    - type: divergence
      lambda: 1.0e-1

  # Ativa a transformação de coordenadas para o mapeamento de altura
  coordinate_transform:
      type: height
      ds_id: [boundary_02] # ID da fatia cromosférica
      validation_ds_id: [validation_boundary_02]

  check_val_every_n_epoch: 1
```

**Observações Importantes:**

-   O `ds_id` em `loss_config` e `coordinate_transform` deve corresponder às suas fatias de dados. `boundary_01` é a primeira, `boundary_02` a segunda, etc.
-   A `lambda` define o peso de cada termo de perda. A `lambda` para `height` controla o quão flexível é o mapeamento de altura.

## Passo 3: Execução da Extrapolação

Com o arquivo de configuração pronto, você pode executar a extrapolação a partir do seu terminal. Certifique-se de que o ambiente `nf2` está ativado.

```bash
nf2-extrapolate --config /caminho/para/seu/arquivo/minha_extrapolacao.yaml
```

O processo de treinamento será iniciado, e os resultados serão salvos no diretório especificado em `base_path`.

---

## Dicas Adicionais

-   **Múltiplas Camadas Cromosféricas:** Você pode adicionar mais de duas fatias. Basta adicioná-las à seção `data.slices` e atualizar os `ds_id` na seção `training`.
-   **Dados Apenas com Componente Vertical:** Se seus dados cromosféricos tiverem apenas a componente vertical (ou line-of-sight, `Bz`), basta especificar apenas esse arquivo no `fits_path` da fatia correspondente. O modelo tentará inferir as componentes horizontais.
-   **Visualização:** Utilize o `paraview` para visualizar os resultados. Você pode converter os arquivos de saída `.nf2` para o formato `.vtk` com o script `nf2-to-vtk`.
