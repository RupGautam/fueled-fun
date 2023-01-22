# Complete K8s deployment project

Summary
=================
Configure and deploy two applications, a frontend and a backend, to a multi-environment setup (development, staging, and production) on AWS. Using Terraform/CDK, Kubernetes (EKS) and Docker in this task. 

The script is designed to make the frontend application public and the backend service private. Implemented auto-scaling and auto-healing for the applications, and ensuring that the applications are properly monitored. 

Keeping security, reliability, and observability in mind as I work on the script, to make sure the final solution is robust. I have ensured the code is well organized, with clear variable naming and is easily readable. I have also provided necessary documentation and diagrams, as well as Helm charts if needed.
![k8s diagram](https://github.com/rupgautam/prescriptivedata.io/blob/master/k8s-diagram.png?raw=true)

Demos
=================
Demo can be access here. 

![](https://i.imgur.com/nT4gVP0.png)


Technology Stack
=================
> List of technologies used in the project.
* Docker
* Terraform
* Kubernetes
* Nginx Ingress controller
* AWS ALB Controller


Table Of Contents
=================
- [Fueled Fun Project](#Fueled-Fun-Project)
- [Summary](#summary)
- [Demos](#demos)
- [Technology Stack](#technology-stack)
- [Table Of Contents](#table-of-contents)
- [Prerequisite](#prerequisite)
- [Docker build](#docker-build)
- [Kubernetes](#kubernetes)
- [Deployments](#deployments)
- [Scaling](#scaling)
- [Monitoring](#monitoring)
- [Project Resources](#project-resources)

Prerequisite
=================
> List of tools which need to be installed locally.
* [Docker](https://docs.docker.com/get-docker/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [helm](https://helm.sh/docs/intro/install/) 


Docker build
=================
Build docker images with three different flavors, Standard, Green, and Blue. We will be using all these three images to create blue-green deployment on k8s cluster. Docker images are build on top of `Alpine 3.10` 

`cd docker/backend && docker build . -f "Dockerfile" -t rupgautam/fueled-fun:backend`

`cd docker/frontend && docker build . -f "Dockerfile" -t rupgautam/fueled-fun:frontend`

`docker push rupgautam/fueled-fun:backend`

`docker push rupgautam/fueled-fun:frontend`

Kubernetes
=================
Installing k8s cluster using prep

```
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
```
```bash
cd terraform

alias tf="terraform"

tf init 

tf plan

# You should see the following output
> Plan: 52 to add, 0 to change, 0 to destroy.

tf apply
```

> What's happening here?
* `terraform` stack will create cluster in zone `us-east-1` with 3 AZs
* Two node groups 1 and 2
* 1 master nodes of type t3.medium
* 2 worker nodes of type t3.medium
* No Network plugin 
* Nodes/Pods/Master will be communicating via `private` topology

Since we are only using private IPs, out external access will be only via the AWS load balancer.
To do so, we will use AWS ALB controller.

`helm repo add eks https://aws.github.io/eks-charts`

Install Target Binding CRDs.

`kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"`

Install the controller.

`helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=Fueled-Fun`

To see if ingress pods are ready, Once ready we are done for setting up our cluster.

`kubectl get pods -n kube-system --watch`

You should see ready states of 2 pods after 5-10 mins


Deployments
=================
All of the below deployments will be done under `fueled-fun-app-${env}` namespaces. 

Create a namespace for our application. In an staging environment 

`kubectl create ns fueled-fun-app-${env}`

Creates deployment for standard image.
`kubectl apply -f deployment.yml`

Creates service with spec `port` and `targetPort` `:3000`. It will select all the deployment which has selector tag of `frontend`

`kubectl apply -f service.yml`

Registers ingress path for `/*` 

`kubectl apply -f ingress.yml`

To check if our deployment has been successful.

`kubectl get deployment,svc,pods -n fueled-fun-app`

`kubectl describe svc service-frontend -n fueled-fun-app` 


To check if our ingress controller has registered our traffic path. AWS ELB takes 5-10min to properly propagate and register our internal IPs. 

`kubectl describe ing ingress-app -n fueled-fun-appScaling

To scale our services, no manual work is needed. Kubernetes can scale up and down as per `daemonSet` and `replicasSet`.

`kubectl scale deployment backend --replicas=5`

`kubectl scale deployment frontend --replicas=5` 

Detailed view on `fueled-fun-app` namespace:

![K8s Auto Healing](https://i.imgur.com/hodfX5d.png)



Auto Healing
=================
Kubernetes Auto Healing refers to the ability of the Kubernetes platform to automatically detect and recover from failures within the system. This includes detecting and replacing failed pods, and restarting or rescheduling containers that have crashed.

Example:
- Kubernetes Auto Healing automatically replaces failed pods
- Kubernetes Auto Healing restarts or reschedules containers that have crashed
- Applications needs livenessProbe and readinessProbe to check the health of the application
- `rollingUpdate` can be used to update application gradually
- A `livenessProbe` checks the running status of each container.
- If a container fails a liveness probe, Kubernetes terminates it and creates a new one according to its policies
- A `readinessProbe` checks a container's ability to service requests or handle traffic.
- If a container fails the readiness probe, Kubernetes removes its IP address from the corresponding pod and make it unavailable until it is terminated and restarted.

### Example of `livenessProbe` and `readinessProbe`:
```
...
spec:
      containers:
      - name: my-web-app
        image: my-web-app:latest
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 3
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 5
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1

```
Monitoring
=================

To install [Prometheus Operator](https://prometheus-operator.dev/docs/operator/design/) 

Create monitring namespaces:

`kubectl create ns monitoring`

```bash
git clone https://github.com/prometheus-operator/kube-prometheus.git

kubectl create -f manifests/setup #setup CRDs

# It it will take about 5-10 to be in ready states

kubectl create -f manifests/
```

![Prometheus stack](https://i.imgur.com/TQKjzg3.png)

To install Grafana stack

```bash
helm install grafana grafana/grafana \
    --namespace monitoring \
    --set persistence.storageClass="gp2" \
    --set persistence.enabled=true \
    --set adminPassword='PASSWORD123' \
    --values grafana.yaml \
    --set service.type=NodePort
```

To access Grafana locally

`kubectl --namespace monitoring port-forward svc/grafana 3000`

To access Grafana via ALB

`kubectl get pods,svc,ing -n monitoring `

You should see something like : `http://k8s-blah-blah-grafana-91f000c26c-114572620.us-east-1.elb.amazonaws.com`

Detailed view of `monitoring` namespace:

![Monitoring](https://i.imgur.com/mXJ88i8.png)


1 | 2
--- | ---
![](https://i.imgur.com/EDyiDBf.png) | ![](https://i.imgur.com/Vpo2pGS.png)
![](https://i.imgur.com/GMQHWMJ.png) | ![](https://i.imgur.com/Vpo2pGS.png)


Project Resources
=================
> I have mostly used kubernetes.io documentation page for most of my work
* Kubernetes Docs
* AWS ALB Ingress Wiki
* Docker Docs
* 90% of Google search 
