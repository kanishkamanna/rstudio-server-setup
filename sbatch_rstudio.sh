#!/bin/bash
#SBATCH --time=0-1:00:00
##be sure to change your account nad permission
#SBATCH --partition=compute
## #SBATCH --account=[your account]
##Resources use 2 CPUs and 20 Gigs
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=20G
##Log file names
#SBATCH --output=logs/rstudio-server-%j.out
#SBATCH --error=logs/rstudio-server-%j.err

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment



cat > rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}
export R_LIBS_USER=${HOME}/R/rocker-rstudio/latest
exec /usr/lib/rstudio-server/bin/rsession "\${@}"
END

chmod +x rsession.sh

mkdir -p ${HOME}/R/rocker-rstudio/latest

export SINGULARITY_BIND="run:/run,database.conf:/etc/rstudio/database.conf,rsession.sh:/etc/rstudio/rsession.sh,var-lib-rstudio-server:/var/lib/rstudio-server"

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

export SINGULARITYENV_USER=$(id -un)
export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15)
# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
cat 1>&2 <<END
1. SSH tunnel from your workstation using the following command:

   ssh -L ${PORT}:localhost:${PORT} ${SINGULARITYENV_USER}@pbc-hpc-is1.bluecat.arizona.edu ssh -L ${PORT}:localhost:${PORT} -N ${HOSTNAME}

   and point your web browser to http://localhost:${PORT}

2. log in to RStudio Server using the following credentials:

   user: ${SINGULARITYENV_USER}
   password: ${SINGULARITYENV_PASSWORD}

When done using RStudio Server, terminate the job by:

1. Exit the RStudio Session ("power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

      scancel -f ${SLURM_JOB_ID}
END

CMD="singularity exec rstudio_latest.sif /usr/lib/rstudio-server/bin/rserver --www-port ${PORT} --auth-none=0 --auth-pam-helper-path=pam-helper --server-user=${SINGULARITYENV_USER} --rsession-path=/etc/rstudio/rsession.sh 1>&2"
echo $CMD
eval $CMD

printf 'rserver exited' 1>&2
