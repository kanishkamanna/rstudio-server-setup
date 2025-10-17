# RStudio Server Setup Using Singularity/Docker Containers

## Prerequisites

* SSH into the HPC account
  
* Check if **Singularity** and **R** is installed on the HPC, by:
    ```{bash}
    module avail
    ```

* If installed, then load the module by:
    ```{bash}
    module load singularity/<version>
    ```

## Steps

1. Create a directory
    ```{bash}
    mkdir singularity
    cd singularity
    ```

2. Pull the latest RStudio container image from Docker
    ```{bash}
    singularity pull docker://rocker/rstudio:latest
    ```

3. Check to see if the `rstudio_<version>.sif` container image is there or not by  `ls` ing.

4. Setup directories to bing to the singularity container
   ```{bash}
   mkdir -p run var-lib-rstudio-server
   printf 'provider=sqlite\ndirectory=/var/lib/rstudio-server\n' > database.conf
   ls
   ```
   This should list the following files in the current directory:
        - `database.conf`
        - `rstudio_<version>.sif`
        - `run/`
        - `var-lib-rstudio-server/`

6. **Optional:** We have to create a port to bind RStudio Server to. The default port is *'8787'*.
   ```{bash}
    printf 'www-port=YOURPORTNUMBERHERE\nwww-address=127.0.0.1\n' > rserver.conf
    ```

> [!WARNING]
> However, there can only be one service per computer/node running on this port without causing issues.
> Therefore, we need to assign ports for each user.
    
7. Next, we have to setup a password to authenticate to our personal RStudio server on the HPC. Then we can run the singularity container.
   ```{bash}
   PASSWORD='yourpassword' singularity exec \
   --bind run:/run,var-lib-rstudio-server:/var/lib/rstudio-server,database.conf:/etc/rstudio/database.conf,rserver.conf:/etc/rstudio/rserver.conf  \
   rstudio_latest.sif \
   /usr/lib/rstudio-server/bin/rserver --auth-none=0 --auth-pam-helper-path=pam-helper --server-user=$(whoami)
   ```

> [!TIP]
> Be sure to run this within SCREEN/TMUX session. After executing this command, the command line won't return and it will appear to hang. This is normal.

We have RStudio server running on the HPC. But, sometimes there may be firewall rule blocking the default port *'8787'*, which is the port RStudio is listening to accept connections.

Here, we need to basically create an SSH tunnel from our local workstation/laptop to the HPC in order to authenticate. This will act as if we are connected locally, but we are actually connecting to the remote server.

8. Now, run the following command:
```{bash}
ssh USERNAME@domain.edu -N -L 8787:localhost:8787
```
Notice, the *8787:localhost:8787* above. This port number may need to be updated when multiple users are using the RStudio server. After running this command, the command line will appear to hang again.

9. Now, on the local workstation/laptop open the internet browser and type in: http://localhost:8787/.

10. You should now be presented with the GUI/IDE for RStudio server in your internet browser.


### Running RStudio via SBATCH script

Currently, we are runnign the resources on the *login node*! For intensive computational work, it is recommended to avoid the login node out of respect for other users. It would be better to run on a CPU node. However, we have to SSH tunnel to get access to this, which adds another layer of complexity.

11. In order to use the CPU nodes we need to run RStudio server via a sbatch script. The `.sh` script can be further modified to change the `SBATCH` specific parameters such as `--time`, `--account`, `--partition`, `--ntasks`, `--cpus-per-task`, `--mem`, etc. 

> [!NOTE]
> Please check out the script `sbatch_rstudio.sh`
> Do change other parts of the code such as `$PATHS` or the HPC domain id.

12. Execute the `sbatch_rstudio.sh` script and check if it is running
   ```{bash}
   sbatch sbatch_rstudio.sh
   squeue -u $USER
   ```

13. The above script automatically can figure out the connection information and printed it in the `.err` file. 
   ```{bash}
    (base) [USERNAME@login-1 singularity]$ cat rstudio-server-4763527.err
    1. SSH tunnel from your workstation using the following command:

    ssh -L 58741:localhost:58741 USERNAME@domain.edu ssh -L 58741:localhost:58741 -N cpu-54

    and point your web browser to http://localhost:58741

    2. log in to RStudio Server using the following credentials:

    user: <USERNAME>
    password: <PASSCODE>

    When done using RStudio Server, terminate the job by:

    1. Exit the RStudio Session ("power") button in the top right corner of the RStudio window)
    2. Issue the following command on the login node:

        scancel -f <JOB-ID>
   ```
   Follow the instructions and connect using the connection URL provided on the local workstation/laptop.

> [!CAUTION]
> Please be aware depending on the `SBATCH` configuration for time, the job will continue to run through this time.
> If done with analysis early, please use `scancel` command to cancel the job when resources are no longer needed.



