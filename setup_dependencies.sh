#!/bin/bash
# setup_dependencies.sh — idempotently install MSHBM's external MATLAB deps.
#
# These are NOT vendored in this repo (CBIG is a 2.6 GB sparse/partial checkout;
# $HOME on Sherlock is only 15 GB). They live under $GROUP_HOME/sw and are
# resolved at runtime via CBIG_CODE_DIR / CIFTI_MATLAB_DIR (with the defaults
# below). FreeSurfer matlab comes from $FREESURFER_HOME/matlab at job time
# (`module load biology freesurfer/8.1.0`), so it is not installed here.
#
# Usage:  bash setup_dependencies.sh
# Safe to re-run: clones only what is missing; leaves existing trees untouched.
set -euo pipefail

SW="${SW_DIR:-$GROUP_HOME/sw}"
CBIG_DIR="${CBIG_CODE_DIR:-$SW/CBIG}"
CIFTI_DIR="${CIFTI_MATLAB_DIR:-$SW/cifti-matlab}"

# Pinned versions (match the fork's historical gitlinks).
CBIG_URL="https://github.com/ThomasYeoLab/CBIG"
CBIG_SHA="2296385910b341c89c14d75c5da8703dec9674d2"   # v0.36.2
CIFTI_URL="https://github.com/Washington-University/cifti-matlab"
CIFTI_SHA="5e2da2068fe79d7ecdf764e17a1370474e32372e"   # v2.2.2-4

# Only these CBIG paths are needed for MSHBM (keeps the sparse checkout small;
# do NOT fetch the full-fat CBIG repo).
CBIG_SPARSE_PATHS=(
  external_packages/SD
  external_packages/matlab
  stable_projects/brain_parcellation/Kong2019_MSHBM
  stable_projects/brain_parcellation/Xue2021_IndCerebellum
  utilities/matlab
)

mkdir -p "$SW"

if [ -d "$CBIG_DIR/.git" ]; then
  echo "[setup] CBIG already present at $CBIG_DIR ($(git -C "$CBIG_DIR" rev-parse --short HEAD)); skipping."
else
  echo "[setup] cloning CBIG (blob:none partial + sparse) -> $CBIG_DIR"
  git clone --filter=blob:none --no-checkout "$CBIG_URL" "$CBIG_DIR"
  git -C "$CBIG_DIR" sparse-checkout init --cone 2>/dev/null || git -C "$CBIG_DIR" sparse-checkout init
  git -C "$CBIG_DIR" sparse-checkout set "${CBIG_SPARSE_PATHS[@]}"
  git -C "$CBIG_DIR" checkout "$CBIG_SHA"
fi

if [ -d "$CIFTI_DIR/.git" ]; then
  echo "[setup] cifti-matlab already present at $CIFTI_DIR ($(git -C "$CIFTI_DIR" rev-parse --short HEAD)); skipping."
else
  echo "[setup] cloning cifti-matlab -> $CIFTI_DIR"
  git clone "$CIFTI_URL" "$CIFTI_DIR"
  git -C "$CIFTI_DIR" checkout "$CIFTI_SHA"
fi

echo "[setup] verifying required functions resolve..."
test -f "$CBIG_DIR/stable_projects/brain_parcellation/Kong2019_MSHBM/step2_estimate_priors/CBIG_MSHBM_estimate_group_priors.m" \
  && echo "  OK CBIG_MSHBM_estimate_group_priors.m" || { echo "  MISSING CBIG estimate_group_priors"; exit 1; }
test -f "$CBIG_DIR/utilities/matlab/FC/CBIG_ComputeCorrelationProfile.m" \
  && echo "  OK CBIG_ComputeCorrelationProfile.m" || { echo "  MISSING CBIG ComputeCorrelationProfile"; exit 1; }
test -f "$CIFTI_DIR/cifti_read.m" && echo "  OK cifti_read.m" || { echo "  MISSING cifti_read"; exit 1; }

echo "[setup] done. Runtime env (defaults shown):"
echo "  export CBIG_CODE_DIR=$CBIG_DIR"
echo "  export CIFTI_MATLAB_DIR=$CIFTI_DIR"
echo "  (FreeSurfer matlab via \$FREESURFER_HOME/matlab after 'module load biology freesurfer/8.1.0')"
