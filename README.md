# Swap MemoryPressure scenarios
## System details
For all scenarios we will be running a cluster with the following configuration:
- Kubernetes minor: 1.22
- Number of nodes: 1
- Node memory: 4 GiB + 8 GiB swap
This configuration might not be optimal for a production environment, but will help us make testing easier.

## Variables:
In order to test possible scenarios, there are a couple of variables which can be combined:

### SwapBehavior
Indicates the configuration used for swap (as documented [here](https://kubernetes.io/blog/2021/08/09/run-nodes-with-swap-alpha/#how-do-i-use-it)). Available scenarios:
- **Limited**: memory limit considers RAM + swap
- **Unlimited**: memory limit considers RAM, swap is unlimited

### Pod memory limit
Indicates how pod memory is limited. Available scenarios:
- **Not set**: Pod has no memory limit set, relies entirely on node's limits.
- **Set**: Pod has memory limit set (500Mi).

### Resource usage
Indicates how much memory a pod usages. Available scenarios:
- **Under the limit**: 250Mi
- **Over the limit**: 1Gi
- **Over available RAM**: 5Gi
- **Over available memory**: 13Gi (memory + swap)

## Setup (GKE specific)
To create a new cluster:
```
gcloud container clusters create swap-experiment \
    --enable-kubernetes-alpha \
    --no-enable-autorepair \
    --no-enable-autoupgrade \
    --num-nodes 1 \
    --cluster-version 1.22.1-gke.1700
```

To connect to a cluster via SSH: `gcloud compute ssh $(kubectl get nodes -o name | sed 's_node/__')'`

To create a swap file and mount it:
```
export SWAPFILE=/home/kubernetes/swapfile
sudo fallocate -l 8G $SWAPFILE
sudo chmod 600 $SWAPFILE
sudo mkswap $SWAPFILE
sudo swapon $SWAPFILE
```

To setup configuration:
1. Edit the kubelet configuration (located on /home/kubernetes/kubelet-config.yaml). Add the following:
    - Under `featureGates`, add:
    ```
    NodeSwap: true
    ```
    - At root, add (considering limited or unlimited):
    ```
    failSwapOn: false
    memorySwap:
        SwapBehavior: "(Limited|Unlimited)Swap"
    ```
    - Under `nodeEvitcito
2. Restart the service via:
    ```
    sudo systemctl restart kubelet
    ``` 

## Test cases
After each test case is complete, run `kubectl delete po chugger` and wait for a couple of minutes. Ensure the pod has been deleted and memory usage is low (via `free --mega`).

Scenario ID | SwapBehavior  | Pod memory limit  | Resource usage        | Command               | Expected pod status   | Expected NodePressure | Expected RAM usage    | Expected swap usage
------------|---------------|-------------------|-----------------------|-----------------------|-----------------------|-----------------------|-----------------------|---------------------
1           | Unlimited     | Not set           | Under the limit       | `./run.sh 250M unset` | Running               | No pressure           | Regular               | None
2           | Unlimited     | Set               | Under the limit       | `./run.sh 250M set`   | Running               | No pressure           | Regular               | None
3           | Unlimited     | Not set           | Over the limit        | `./run.sh 1G unset`   | Running               | No pressure           | Regular               | None
4           | Unlimited     | Set               | Over the limit        | `./run.sh 1G set`     | Running               | No pressure           | Regular               | Regular
5           | Unlimited     | Not set           | Over available RAM    | `./run.sh 5G unset`   | Running               | No pressure           | Heavy                 | Regular
6           | Unlimited     | Set               | Over available RAM    | `./run.sh 5G set`     | Running               | No pressure           | Heavy                 | Regular
7           | Unlimited     | Not set           | Over available memory | `./run.sh 13G unset`  | Running               | Pressure              | Heavy                 | Heavy
8           | Unlimited     | Set               | Over available memory | `./run.sh 13G set`    | Exit                  | Pressure              | Heavy                 | Heavy
9           | Limited       | Not set           | Under the limit       | `./run.sh 250M unset` | Running               | No pressure           | Regular               | None
10          | Limited       | Set               | Under the limit       | `./run.sh 250M set`   | Running               | No pressure           | Regular               | None
11          | Limited       | Not set           | Over the limit        | `./run.sh 1G unset`   | Running               | No pressure           | Regular               | None
12          | Limited       | Set               | Over the limit        | `./run.sh 1G set`     | Exit                  | No pressure           | Regular               | None
13          | Limited       | Not set           | Over available RAM    | `./run.sh 5G unset`   | Running               | No pressure           | Heavy                 | Regular
14          | Limited       | Set               | Over available RAM    | `./run.sh 5G set`     | Exit                  | No pressure           | Regular               | Regular
15          | Limited       | Not set           | Over available memory | `./run.sh 13G unset`  | Running               | Pressure              | Heavy                 | Heavy
16          | Limited       | Set               | Over available memory | `./run.sh 13G set`    | Exit                  | Pressure              | Heavy                 | Heavy
