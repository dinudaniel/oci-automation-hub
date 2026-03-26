# Kyverno demo

## Getting started

This stack will deploy an OKE cluster with one nodepool with one worker node to demonstrate how Kyverno works in OKE in OCI.
In addition it will deploy 2 VM's, a bastion VM and an operator VM to be able to manage the cluster.
The stack will install Kyverno as well and will copy a folder (_kyverno_) to operator VM.

## How to deploy?

### Prerequisites

- The account used to deploy the ORM stack must be part of a group that has the following permissions described [here](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengpolicyconfig.htm#policyforgroupsrequired)


### Deploy via ORM:

- Clone this repo
- Create a new stack in Resource Manager
- Upload the folder configuration files **oci_oke_kyverno** 
- Configure the variables
- Apply the stack
- At the end you should see an output with bastion and operator IP's
- These will be used to ssh to operator VM
- You may use something like this in your ssh config file

```
Host OKE-kyv-test1-oper
  HostName <operator IP>
  ProxyCommand ssh -W %h:%p -i <path to your ssh private key> opc@<bastion IP>
  IdentityFile <path to your ssh private key>
  User opc
  HostKeyAlias OKE-kyv-test1-oper
```

## How to run the demo

- Connect to the operator VM
- Make sure Kyverno resources are installed. Run the below to check

```
kubectl get all -n kyverno
```
You should get an output like below. The pods must be in Running state. Deployments and replicas must be Ready and Available.

```
opc@o-kyverno:~/kyverno/01_validation[opc@o-kyverno 01_validation]$ k get all -n kyverno
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/kyverno-admission-controller-5bcbdff469-d46xx    1/1     Running   0          19h
pod/kyverno-background-controller-7c7d4dbbc9-btpf9   1/1     Running   0          19h
pod/kyverno-cleanup-controller-745cbc6f8d-sjhnq      1/1     Running   0          19h
pod/kyverno-reports-controller-7867ffd654-4b7sw      1/1     Running   0          19h

NAME                                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/kyverno-background-controller-metrics   ClusterIP   10.96.212.125   <none>        8000/TCP   19h
service/kyverno-cleanup-controller              ClusterIP   10.96.205.173   <none>        443/TCP    19h
service/kyverno-cleanup-controller-metrics      ClusterIP   10.96.56.125    <none>        8000/TCP   19h
service/kyverno-reports-controller-metrics      ClusterIP   10.96.26.108    <none>        8000/TCP   19h
service/kyverno-svc                             ClusterIP   10.96.66.24     <none>        443/TCP    19h
service/kyverno-svc-metrics                     ClusterIP   10.96.102.138   <none>        8000/TCP   19h

NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kyverno-admission-controller    1/1     1            1           19h
deployment.apps/kyverno-background-controller   1/1     1            1           19h
deployment.apps/kyverno-cleanup-controller      1/1     1            1           19h
deployment.apps/kyverno-reports-controller      1/1     1            1           19h

NAME                                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/kyverno-admission-controller-5bcbdff469    1         1         1       19h
replicaset.apps/kyverno-background-controller-7c7d4dbbc9   1         1         1       19h
replicaset.apps/kyverno-cleanup-controller-745cbc6f8d      1         1         1       19h
replicaset.apps/kyverno-reports-controller-7867ffd654      1         1         1       19h
```
**1. Demonstrate how ValidatingPolicy works**

- Change directory to kyverno/01_validation
- Run the below to create a namespace _demo_ where we will test the policies
```
kubectl apply -f namespace.yaml 
```
- Run the below to create a policy that will enforce deployments to have a number of 3 replicas and a label named _team_
```
kubectl apply -f k_depl_rules_namespace.yaml 
```
- Check the policy
```
kubectl get policies -n demo
```
- You shoud see something like 
```
NAME                        ADMISSION   BACKGROUND   READY   AGE   MESSAGE
validation-for-deployment   true        true         True    35s   Ready
```
- Now we will try to create a deployment that does not has the number of desired replicas nor a label named _team_
- It will failed. Run the below:

```
kubectl apply -f depl.yaml 
```
- You will get an error about the number of replicas:
```
Error from server: error when creating "depl.yaml": admission webhook "validate.kyverno.svc-fail" denied the request: 
resource Deployment/demo/nginx-deployment was blocked due to the following policies 
validation-for-deployment:
  check-for-replica: 'validation error: The replica must set to >=3. rule check-for-replica
    failed at path /spec/replicas/'
  check-for-team-label: 'validation error: The label ''team'' is required for all
    deployments. rule check-for-team-label failed at path /metadata/labels/team/'
```
- Open the _depl.yaml_ file and change the number of replicas from 2 to 3
- Save the file an run again 
```
kubectl apply -f depl.yaml 
```
- It will fails again now because of a missing label _team_

```
Error from server: error when creating "depl.yaml": admission webhook "validate.kyverno.svc-fail" denied the request: 
resource Deployment/demo/nginx-deployment was blocked due to the following policies 
validation-for-deployment:
  check-for-team-label: 'validation error: The label ''team'' is required for all
    deployments. rule check-for-team-label failed at path /metadata/labels/team/'
```

- Open the file again and uncomment label team:  _team: frontend_
- Save the file and run the command below:

```
kubectl apply -f depl.yaml 
```

- It should work fine now
- You may check the depl if you want

```
kubectl get deployments -n demo
```

- Delete the deployment and the policy
- Do not delete the namespace

```
kubectl delete -f k_depl_rules_namespace.yaml 
kubectl delete -f depl.yaml
```

**2. Demonstrate how MutatingPolicy works**

- This policy will mutate a resource by adding a label if does not exists
- Go to 02_mutate folder
- Run the below to create a cluster wide policy
```
kubectl apply -f k_mutate.yaml 
```
- Check the policy
```
kubectl get clusterpolicies 
```
- Now create the deployment. Mind there is no label named _team_ 
```
kubectl apply -f depl.yaml 
```
- Check the deployment labels
```
kubectl get deployments --show-labels -n demo
```
- You should see a label named _team_ was added

```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE   LABELS
nginx-deployment   2/2     2            2           27s   app=nginx,team=bravo
```

- Clean up
```
kubectl delete -f depl.yaml 
kubectl delete -f k_mutate.yaml
```
**3. Demonstrate how GeneratingPolicy works** 

- This policy will clone a secret every time a namespace is created. The secret will be cloned in the new namespace 
- We need to create a role first as Kyverno does not have privileges to create secrets.
- Change dir to 03_generate
- Run the below
```
kubectl apply -f cluster_role.yaml
```
- Create a secret in the default namespace. This secret is being cloned by the policy when a new namespace will be created
```
kubectl apply -f create_secret.yaml 
kubectl get secrets -n default
```

- Create the Kyverno policy
```
kubectl apply -f k_generate.yaml 
```

- Create a new namespace

```
kubectl create ns demo1
```

- As soon as this NS is created the secret _regcred_ will be created in the new namespace
```
kubectl get secrets -n demo1
```

- Cleanup 
```
kubectl delete -f k_generate.yaml 
kubectl delete secret regcred -n demo1
kubectl delete ns demo1
```

## Destroy the OKE cluster

- From Resource Manager chose the stack you created and click on Destroy button