#!/bin/bash
show_help() {
cat << EOF
Usage:
  $(basename "$0") [GENOMES] [TREE] [RESULT_DIR]

Description:
  This script runs the SPP-exact pipeline for ancestral genome reconstruction.
  It converts the input tree, infers marker multiplicities, constructs the
  adjacency space, builds and solves an ILP formulation, and parses the results.

Arguments:
  GENOMES      Input genome file in UniMoG format.
               Default: genomes.ug

  TREE         Input phylogenetic tree in Newick format.
               Default: tree.nwk

  RESULT_DIR   Output directory where results will be written.
               Default: spp-results-<GENOMES base>-<TREE base>

Output:
  A result directory containing:
    work_dir/                  Intermediate files and logs
    inferred_adjacencies.txt   Final inferred adjacencies

Environment:
  The script expects the SPP-exact Python scripts to be located in:
    ../scripts  (relative to this script)

  Gurobi must be installed and callable from Python.

Options:
  -h, --help    Show this help message and exit.

Example:
  $(basename "$0") genomes.ug tree.nwk my_results

EOF
}

for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        show_help
        exit 0
    fi
done

# Error if too many positional arguments
if [[ "$#" -gt 3 ]]; then
    echo "Error: Too many arguments." >&2
    echo "" >&2
    show_help
    exit 1
fi

SCRIPT_DIR=$(realpath "$(dirname "$0")")
SPP_SCRIPT_HOME=$(realpath "$SCRIPT_DIR/../scripts")

TIME_LIMIT=600 # 10 minutes
THREADS=8

genomes="${1:-genomes.ug}"
tree="${2:-tree.nwk}"

BASE_GNM=$(echo "$genomes" | cut -d "." -f 1)
BASE_TREE=$(echo "$tree" | cut -d "." -f 1)
RES_DIR="${3:-spp-results-$BASE_GNM-$BASE_TREE}"
WORK_DIR="$RES_DIR/work_dir"

echo "Using spp-exact scripts found here:" "$SPP_SCRIPT_HOME"

mkdir -p "$WORK_DIR"

set -euo pipefail
set -euo pipefail
echo "Converting tree format"
python3 $SPP_SCRIPT_HOME/nwk2tabular.py $tree > $WORK_DIR/tree_raw.tab
echo "Inferring marker copy numbers"
python3 $SPP_SCRIPT_HOME/cost_alg.py $genomes $tree --input_format unimog --output_dir $WORK_DIR 2> $WORK_DIR/mfreqs.log
echo "Building adjacency space as degenerate genomes"
python3 $SPP_SCRIPT_HOME/add_all_adjacencies_inner.py $WORK_DIR/tree_raw.tab $genomes $WORK_DIR/ranges.tsv  --write-adjacencies $WORK_DIR/adjacency_space.tab --write-tree $WORK_DIR/tree_filtered.tab &> $WORK_DIR/deggnms.log
echo "Creating ILP"
python3 $SPP_SCRIPT_HOME/spp_dcj.py -a 1 -l $WORK_DIR/tree_filtered.tab $WORK_DIR/adjacency_space.tab -m $WORK_DIR/node_ids.tab --write-phylogeny-edge-ids $WORK_DIR/tree_ids.tab --fix-extremity-edges --affine-extension-target $WORK_DIR/scores.tsv > $WORK_DIR/ilp.ilp 2> $WORK_DIR/spp.log
echo "Solving ILP with gurobi"
python3 $SPP_SCRIPT_HOME/gurobi_tree.py $WORK_DIR/ilp.ilp $WORK_DIR/ilp.sol $WORK_DIR/tree_ids.tab  --timelim $TIME_LIMIT -t $THREADS  &> $WORK_DIR/gurobi.log
echo "Parsing solution"
python3 $SPP_SCRIPT_HOME/parse_solution.py $WORK_DIR/tree_ids.tab $WORK_DIR/adjacency_space.tab $WORK_DIR/node_ids.tab $WORK_DIR/ilp.sol -l --write-adjacencies $WORK_DIR/sol_adjacencies.tab --no-relabel-adjacencies &> $WORK_DIR/parsesol.log
echo "Inferring adjacencies of genomes filtered from tree"
python3 $SPP_SCRIPT_HOME/infer_filtered_adjacencies.py $WORK_DIR/tree_raw.tab $genomes $WORK_DIR/sol_adjacencies.tab > $WORK_DIR/flt_adjacencies.tab 2> $WORK_DIR/postsol.log
cat $WORK_DIR/sol_adjacencies.tab $WORK_DIR/flt_adjacencies.tab > $RES_DIR/inferred_adjacencies.txt
echo "Done"
