# SPP-exact

## Introduction

`SPP-exact` solves the **Small Parsimony Problem (SPP)** under the **DCJ-indel model** for natural genomes.

The Small Parsimony Problem aims to reconstruct ancestral genome structures on a fixed phylogenetic tree such that the total rearrangement cost along the tree is minimized. Genomes are represented as ordered sequences of **oriented markers**, allowing arbitrary marker copy numbers (natural genomes model).

`SPP-exact` provides an exact ILP formulation of SPP under the DCJ-indel model. The method reduces the ILP search space by using an explicit surcharge for deleted and inserted markers and constraining the adjacency space using properties of the DCJ-indel distance when distances are small. This makes exact reconstruction feasible for small and recently diverged genomes, such as plasmids.

---

## Requirements

We recommend using the provided Conda environment.

### 1. Create Conda environment

```bash
conda env create -f environment.yml
conda activate spp-exact
```

This installs all required dependencies.

### 2. Gurobi License

A valid **Gurobi license** is required to run the ILP solver.

After installing the Conda environment, make sure that:

- you have obtained a valid Gurobi license, and  
- the license is properly configured (e.g. via `grbgetkey` or a `gurobi.lic` file).

See:
- https://www.gurobi.com/ 
- https://support.gurobi.com/hc/en-us/articles/12872879801105-How-do-I-retrieve-and-set-up-a-Gurobi-license

---

## Input

The pipeline requires:

- **Genomes** in UniMoG format (`.ug`, see also here: https://gitlab.ub.uni-bielefeld.de/gi/ding-cf/-/blob/main/unimog-unofficial.md)
- **Phylogenetic tree** in Newick format (`.nwk`)

Example input files are provided in the `example/` directory.

---

## Quick Start

Run the example pipeline:

```bash
cd example
bash run.sh genomes.ug tree.nwk my_results
```

If no arguments are provided, default filenames are used:

```bash
bash run.sh
```

---

## Pipeline Overview

The pipeline performs the following steps:

1. Convert Newick tree to internal tabular format  
2. Infer admissible marker multiplicity ranges  
3. Construct adjacency search space  
4. Build ILP formulation  
5. Solve ILP using Gurobi  
6. Parse and postprocess the solution  
7. Output inferred ancestral adjacencies  

Results are written to:

```
<RESULT_DIR>/
├── work_dir/                  # intermediate files and logs
└── inferred_adjacencies.txt   # final inferred adjacencies
```

---

## Script Usage

```bash
run.sh [GENOMES] [TREE] [RESULT_DIR]
```

### Arguments

| Argument     | Description                       | Default |
|--------------|-----------------------------------|----------|
| `GENOMES`    | Genome file (UniMoG format)       | `genomes.ug` |
| `TREE`       | Phylogenetic tree (Newick format) | `tree.nwk` |
| `RESULT_DIR` | Output directory                  | `spp-results-<GENOMES>-<TREE>` |

Display help:

```bash
bash run.sh --help
```

---

## Output

The main result file:

```
inferred_adjacencies.txt
```

contains the reconstructed adjacencies for all internal nodes of the phylogeny.

Intermediate files, ILP models, and solver logs are stored in `work_dir/`.

---

## Reproducing Experiments

Snakemake workflows to reproduce the experiments from the paper are available in the `experiments/` directory.

