# Introduction into Understanding Istio Certificates and Authorization Policies

This training module will introduce you to basic concepts of how Istio utilizes certificate authorities, certificate distribution in the mesh to the istio-proxy sidecar for use of mTLS for Kubernetes workloads, as well as showing a simplified version of how Istio authorization policies work to secure traffic in the mesh. There will also be highlights of slight configuration changes to Istio for the managed AKS Azure Service Mesh.

## Before you begin

Please follow this walkthrough step by step. The creation of a new AKS cluster and installing the Azure Service Mesh addon new is needed for scenarios and configuration highlights in later tasks. Having an existing AKS cluster and/or deployment of the AKS Azure Service Mesh addon my alter some desired results of this specific walkthrough.

### Clone the Istio Upstream GitHub repo

```
git clone https://github.com/istio/istio.git
```

### Setup environment variables

```bash
export CLUSTER_NAME=asm-levelup-demo \
export RESOURCE_GROUP=asm-levelup-demo \
export LOCATION=eastus2
```

**_NOTE:_** At the time of creating this document, the Azure Service Mesh addon is in preview. The following verification steps of having the aks-preview extension may not be applicable once the addon is generally available on Azure.

### Verify Azure CLI and aks-preview extension versions

The add-on requires:

- Azure CLI version 2.44.0 or later installed.
- `aks-preview` Azure CLI extension of version 0.5.133 or later installed

You can run `az --version` to verify above versions.

To install the aks-preview extension, run the following command:

```bash
az extension add --name aks-preview
```

Run the following command to update to the latest version of the extension released:

```bash
az extension update --name aks-preview
```

### Register the _AzureServiceMeshPreview_ feature flag

Register the `AzureServiceMeshPreview` feature flag by using the [az feature register][az-feature-register] command:

```bash
az feature register --namespace "Microsoft.ContainerService" --name "AzureServiceMeshPreview"
```

It takes a few minutes for the feature to register. Verify the registration status by using the [az feature show][az-feature-show] command:

```bash
az feature show --namespace "Microsoft.ContainerService" --name "AzureServiceMeshPreview"
```

When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider by using the [az provider register][az-provider-register] command:

```bash
az provider register --namespace Microsoft.ContainerService
```

## Install AKS Azure Service Mesh add-on at the time of cluster creation

```bash
az group create --name ${RESOURCE_GROUP} --location ${LOCATION}

az aks create -g ${CLUSTER_NAME} -n ${RESOURCE_GROUP} --node-vm-size standard_d2_v2 --node-count 3 --enable-managed-identity -o none
```

### Verify successful installation

To verify the Istio add-on is installed on your cluster, run the following command:

```bash
az aks show --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}  --query 'serviceMeshProfile.mode'
```

Confirm the output shows `Istio`.

Use `az aks get-credentials` to the credentials for your AKS cluster:

```bash
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}
```

Use `kubectl` to verify that `istiod` (Istio control plane) pods are running successfully:

**_NOTE:_** The Istio control plan is installed in the `aks-istio-system` namespace as an addon and not the default istio-system namepace.

```bash
kubectl get pods -n aks-istio-system
```

Confirm the `istiod` pod has a status of `Running`. For example:

```
NAME                              READY   STATUS    RESTARTS   AGE
istiod-asm-1-17-cdb49b9bd-5q4lq   1/1     Running   0          18h
istiod-asm-1-17-cdb49b9bd-ttlbq   1/1     Running   0          18h
```

## Istio's Security Architecture

![Alt text](./images/arch-sec.svg "Istio's Security Architecture")

## View the Certificates Used for Mesh mTLS Encryption

View the secrets residing in the `aks-istio-system` namespace.

```bash
kubectl get secret -n aks-istio-system
```

```
NAME                                                         TYPE                 DATA   AGE
istio-ca-secret                                              Opaque               4      22h
sh.helm.release.v1.azure-service-mesh-istio-discovery.v498   helm.sh/release.v1   1      100s
sh.helm.release.v1.azure-service-mesh-istio-discovery.v499   helm.sh/release.v1   1      39s
```

We can see the CA keys used for the mesh is contained in the `istio-ca-secret` secret. If we desribe the secret we can see the files container the certificate and signing key.

```bash
kubectl describe secret -n aks-istio-system istio-ca-secret
```

```
Name:         istio-ca-secret
Namespace:    aks-istio-system
Labels:       <none>
Annotations:  <none>

Type:  istio.io/ca-root

Data
====
ca-cert.pem:     1094 bytes
ca-key.pem:      1675 bytes
cert-chain.pem:  0 bytes
key.pem:         0 bytes
root-cert.pem:   0 bytes
```

The certificates are also deployed to every namespace on the cluster, with the execption of the `kube*` namespaces as a configmap. The certificates in the configmap are used in the boostrapping process of the istio-proxy sidecar when the namespace is configured for side-car injection.

View the `istio-ca-root-cert` configmap that exists in all namespaces, with the exception of namespaces that are pre-fixed with `kube*`.

```bash
kubectl get cm -A | grep "istio-ca-root-cert"
```

```
aks-istio-ingress   istio-ca-root-cert                      1      2d1h
aks-istio-system    istio-ca-root-cert                      1      2d1h
default             istio-ca-root-cert                      1      2d1h
foo                 istio-ca-root-cert                      1      2d1h
```

Describe the `istio-ca-root-cert` in the default namespace to see the root certificate. This is exactly the same in all other namespaces that contain the configmap.

```bash
kubectl describe cm istio-ca-root-cert
```

```
Name:         istio-ca-root-cert
Namespace:    default
Labels:       istio.io/config=true
Annotations:  <none>

Data
====
root-cert.pem:
----
-----BEGIN CERTIFICATE-----
MIIC/DCCAeSgAwIBAgIQL5tHvsJjbrCQs3oXrroE9TANBgkqhkiG9w0BAQsFADAY
MRYwFAYDVQQKEw1jbHVzdGVyLmxvY2FsMB4XDTIzMDgxNjEzNDUzOFoXDTMzMDgx
MzEzNDUzOFowGDEWMBQGA1UEChMNY2x1c3Rlci5sb2NhbDCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAOQgjcE22ItUqXjPjNiOEEaqYwqZBdeMLuAUs6jR
xaMSzfcvw+kp2NBZmZgJqKFl1APuJiZtBc7kQevfMzH+jHHbPX36mPA9rNqlVrRZ
ptkVeQNukKQ4ocya5OHoa/LVGQfnVIqzCZIILqr9jS6J4fuP1Uv+FZ3GxOB9nUfP
H/3L14ZqRgltQ8VTDdredgp4fu6GFzeD+U9BpPnQO+YheMZ7dGFkU0n9dh5bmtoW
K//UFDFhiPOXa7skHtAE0iBpg9JlNtG1/aTLJbZntCZ+q4+vIm41QTNhnipQ9Aqv
IqzE2Pu9h15/PxgG2doSDwBv4VwiJkQL81mY0gs60my0v3sCAwEAAaNCMEAwDgYD
VR0PAQH/BAQDAgIEMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFNKuUwMK0KuP
vT+4x86qYlg8lGwOMA0GCSqGSIb3DQEBCwUAA4IBAQB5KLOt6NUAOIdfpY6rQESo
YPCtBYvDVDax41VBTlNmtvLG9JkbvHZHUrKlKpwqUQda4dmJ/oPAXvmdvWmnpggY
byi+PbgjrOrZRJsqqCEhIxoTURUjKDitNPJPsHaMFCMhfb8WGdRHgTHJ+kXKwrl8
A6FYi4RfKiImzEttAKSvz7kD7R8Im8Ev2JPH50ixx3xAgp/J8ztI9I7IXhVs2WIF
gc+QCptzlm6Z6e2UhXPdIr5e3uUzYcKEvnEMcal0l4bQRPKTBSfc/9nSWbeoov2U
li/AVqvWaczNvw3HrOTGsu1bc5upkqvCV8BpkJtmDoBdYkdVfQiw/5Bn/8ebyCEX
-----END CERTIFICATE-----


BinaryData
====

Events:  <none>
```

View the certificate issuer from the configmap.

```bash
kubectl get cm istio-ca-root-cert -o jsonpath='{.data.root-cert\.pem}' | openssl x509 -text -noout | grep "Issuer"
```

```
Issuer: O = Istio, CN = Root CA
```

View the `istio-ca-root-cert` mounted on the Istiod control plane pods.

```bash
kubectl describe -n aks-istio-system po $(kubectl get po -n aks-istio-system -l app=istiod -o jsonpath={.items[0]..metadata.name}) | grep -C 3 istio-csr-ca
```

```
Mounts:
      /etc/cacerts from cacerts (ro)
      /var/run/secrets/istio-dns from local-certs (rw)
      /var/run/secrets/istiod/ca from istio-csr-ca-configmap (ro)
      /var/run/secrets/istiod/tls from istio-csr-dns-cert (ro)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-zwzxw (ro)
      /var/run/secrets/remote from istio-kubeconfig (ro)
--
    Type:        Secret (a volume populated by a Secret)
    SecretName:  istiod-tls
    Optional:    true
  istio-csr-ca-configmap:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      istio-ca-root-cert
    Optional:  true
```

## Setup and Deploy Demo Workloads

Create the `foo` namespace

```bash
kubectl create ns foo
```

From the Istio cloned repo directory, deploy both the httpbin and sleep applications into the `foo` namespace.

```bash
kubectl apply -f samples/sleep/sleep.yaml -n foo
kubectl apply -f samples/httpbin/httpbin.yaml -n foo
```

Verify both applications are up and running and notice they do not have the istio-proxy side-car injected.

```bash
kubectl get po -n foo
```

```
NAME                       READY   STATUS    RESTARTS   AGE
httpbin-6f844bf9bd-lv2j2   1/1     Running   0          10m
sleep-754d65bfd6-k8t5w     1/1     Running   0          13m
```

Test the connectivity from the sleep app to the httpbin app `html` endpoint.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html
```

You should see an html response returned.

```
<!DOCTYPE html>
<html>
  <head>
  </head>
  <body>
      <h1>Herman Melville - Moby-Dick</h1>

      <div>
        <p>
...
```

Test the connectivity from the sleep app to the httpbin app `header` endpoint.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/headers
```

**_NOTE:_** Pay special attention to the header output here for comparison before the applications are managed in the mesh

```
{
  "headers": {
    "Accept": "*/*",
    "Host": "httpbin.foo:8000",
    "User-Agent": "curl/8.2.1",
  }
}
```

## Setup the foo namespace to be managed by Azure Service Mesh

For recap let's review the `httpbin` and `sleep` pods in the `foo` namespace.

```bash
kubectl get po -n foo
```

```
NAME                       READY   STATUS    RESTARTS   AGE
httpbin-6f844bf9bd-lv2j2   1/1     Running   0          10m
sleep-754d65bfd6-k8t5w     1/1     Running   0          13m
```

We will now lable the `foo` namespace to be managed by Azure Service Mesh.

**_NOTE:_** Labeling the namespace uses a rev of the version of Istio to manage the particular namespace. This is done to distinquish namespaces that are managed by different versions of Istio. This will be discussed in upcoming upgrade documentation for the addon.

```bash
kubectl label namespace foo istio.io/rev=asm-1-17

kubectl describe ns foo | grep Labels
```

```
Labels:       istio.io/rev=asm-1-17
```

Now that we have the namespace labeled to be managed by Azure Service Mesh, we now need to restart the deployments to get the istio-proxy sidecar injection. For now we will only restart the `httpbin` deployment to test some scenarios.

```bash
kubectl -n foo rollout restart deployment/httpbin
```

View that only the the `httpbin` pod has the istio-proxy sidecar.

```bash
kubectl get po -n foo
```

```
NAME                       READY   STATUS    RESTARTS   AGE
httpbin-6f844bf9bd-lv2j2   2/2     Running   0          1m
sleep-754d65bfd6-k8t5w     1/1     Running   0          20m
```

With only the `httpbin` pod having the istio-proxy sidecar, test connectivity to `httpbin` from sleep. What do you think will happen from the output?

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html
```

`httpbin` successfuly returned the html page to `sleep`.

```
<!DOCTYPE html>
<html>
  <head>
  </head>
  <body>
      <h1>Herman Melville - Moby-Dick</h1>

      <div>
        <p>
...
```

Why did this happen if `httpbin` is managed by Azure Service Mesh and has a sidecar with certificates and `sleep` does not? This is due to a setting in Istio called [Peer Authentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/), which defines how traffic will be tunneled to the sidecar. The default mode for Peer Authentication is `permissive`, which allows connections either in plaintext or mTLS if a handshake is facilitated. Since the `sleep` application is not requiring mTLS, `httpbin` will accept the request as plaintext permissive mode. To prohibit `httpbin` from accepting plaintext request, the Peer Authentication mode will need to be set to `strict`.

Deploy Peer Authentication strict mode to the foo namespace.

```bash
kubectl apply -n foo -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF
```

Test connectivity from `sleep` to `httpbin` with Peer Authentication strict mode enabled.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html
```

We can now see the mesh policy in use. All traffic in the mesh for namespace `foo` must use mTLS.

```
curl: (56) Recv failure: Connection reset by peer
command terminated with exit code 56
```

Restart the `sleep` deployment for the istio-proxy sidecar injection.

```bash
kubectl -n foo rollout restart deployment/sleep
```

Now verify connectivity between `httpbin` and `sleep` now that both pods have istio-proxy sidecars managing traffic.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html
```

```
<!DOCTYPE html>
<html>
  <head>
  </head>
  <body>
      <h1>Herman Melville - Moby-Dick</h1>

      <div>
        <p>
...
```

Now let's take a look at the response from `httpbin` headers endpoint.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/headersheaders
```

Notice the additional headers added by the istio-proxy (Envoy) sidecar.

```bash
{
  "headers": {
    "Accept": "*/*",
    "Host": "httpbin.foo:8000",
    "User-Agent": "curl/8.2.1",
    "X-B3-Parentspanid": "66043c44fe20804b",
    "X-B3-Sampled": "0",
    "X-B3-Spanid": "96b778abb940294a",
    "X-B3-Traceid": "0b1ddf33bae82d5066043c44fe20804b",
    "X-Envoy-Attempt-Count": "1",
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/foo/sa/httpbin;Hash=de765c8483603413515e155bd317bb927943b7aa55e5e2f1c6f81d4dea81a7de;Subject=\"\";URI=spiffe://cluster.local/ns/foo/sa/sleep"
  }
}
```

For distributed tracking, using either Jaeger, Zipkin, etc, Istio integrates using Envoy-based tracing using B3 headers and Envoy-generated request IDs.

To see the certificate chain of each workload deployment, you can output the secret data containing the TLS certificates.

```bash
istioctl proxy-config secret -n foo deployment/httpbin -o json | jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | base64 --decode > httpbin-cert-chain.pem

cat httpbin-cert-chain.pem

istioctl proxy-config secret -n foo deployment/sleep -o json | jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | base64 --decode > sleep-cert-chain.pem

cat sleep-cert-chain.pem
```

The output will be the certificate chain of each workload. You should be able to match the bottom certificate to the Root CA certificate desribed in the output of the `istio-ca-root-ca` configmap from earlier.

## Change the Root CA certificates for the Mesh

⚠️ WARNING ⚠️

> The following instructions are not meant for a production environment. Please plan production swapping of CA certificates in the mesh accordingly.

The following proceedure will create a new Root CA, then create an Intermediate CA for which the mesh will issue and sign new certificates for workloads in the mesh.

**_NOTE:_** Please ensure you are running these commands in the Istio repo cloned directory

Create a new root CA.

```bash
mkdir -p certs

cd certs

make -f ../tools/certs/Makefile.selfsigned.mk root-ca
```

```
generating root-key.pem
generating root-cert.csr
generating root-cert.pem
Certificate request self-signature ok
subject=O = Istio, CN = Root CA
```

Create the intermediate CA.

```bash
make -f ../tools/certs/Makefile.selfsigned.mk myintca-cacerts
```

```
generating myintca/ca-key.pem
generating myintca/cluster-ca.csr
generating myintca/ca-cert.pem
Certificate request self-signature ok
subject=O = Istio, CN = Intermediate CA, L = myintca
generating myintca/cert-chain.pem
Intermediate inputs stored in myintca/
done
rm myintca/intermediate.conf myintca/cluster-ca.csr
```

Delete the existing `istio-ca-secret` secret in the `aks-istio-system` namespace.

```bash
kubectl delete secret istio-ca-secret -n aks-istio-system
```

Create a new `istio-ca-secret` secret in the `aks-istio-system` namespace using the newly generated certificate and signing key.

```bash
kubectl create secret generic istio-ca-secret -n aks-istio-system \
      --from-file=myintca/ca-cert.pem \
      --from-file=myintca/ca-key.pem \
      --from-file=myintca/root-cert.pem \
      --from-file=myintca/cert-chain.pem
```

```
secret/istio-ca-secret created
```

Restart the istiod (control plane) pods.

```bash
kubectl -n aks-istio-system rollout restart deployment/istiod-asm-1-17
```

Check that the pods have successfuly restarted.

```bash
kubectl get po -n aks-istio-system
```

```
NAME                              READY   STATUS    RESTARTS   AGE
istiod-asm-1-17-cdb49b9bd-bn5gh   1/1     Running   0          26s
istiod-asm-1-17-cdb49b9bd-jbts9   1/1     Running   0          26s
```

Describe the new Root CA certificate.

```bash
kubectl describe cm istio-ca-root-cert
```

The certificate signature should be different from the earlier CA configmap.

```
Name:         istio-ca-root-cert
Namespace:    default
Labels:       istio.io/config=true
Annotations:  <none>

Data
====
root-cert.pem:
----
-----BEGIN CERTIFICATE-----
MIIFeDCCA2CgAwIBAgIUPnXzREbd4NJF03hZMc18Qir3+BAwDQYJKoZIhvcNAQEL
BQAwIjEOMAwGA1UECgwFSXN0aW8xEDAOBgNVBAMMB1Jvb3QgQ0EwHhcNMjMwODE4
MTk0NDQ0WhcNMzMwODE1MTk0NDQ0WjA8MQ4wDAYDVQQKDAVJc3RpbzEYMBYGA1UE
AwwPSW50ZXJtZWRpYXRlIENBMRAwDgYDVQQHDAdteWludGNhMIICIjANBgkqhkiG
9w0BAQEFAAOCAg8AMIICCgKCAgEAxZPWUkUiFmh5HEwU10SQAq7TMF1mjek6Zxt7
...
```

As of now both the `sleep` and `httpbin` pods have not been restarted and they both retain thier certs signed by the previous CA. As long as they have not been restarted since the CA change, connectivity between the two applications should still work.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html
```

Restart only the `httpbin` deployment to initiate a CSR (Certificate Signing Request) from the new CA.

```bash
kubectl -n foo rollout restart deployment/httpbin
```

Once the new `httpbin` pod has restarted and is running, retry the connectivity from `sleep` to `httpbin`

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html
```

You should receive the following error.

```bash
upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection failure, transport failure reason: TLS error: 268435581:SSL routines:OPENSSL_internal:CERTIFICATE_VERIFY_FAILED
```

Check the certificates of both `sleep` and `httpbin`.

Checking `sleep`

```bash
istioctl proxy-config secret -n foo $(kubectl get pods -n foo -o jsonpath='{.items..metadata.name}' --selector app=sleep) -o json | jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | base64 --decode | openssl x509 -text -noout | vim -
```

Notice who the issuer is for the `sleep` workload

```
Issuer: O = cluster.local
```

Checking `httpbin`

```bash
istioctl proxy-config secret -n foo $(kubectl get pods -n foo -o jsonpath='{.items..metadata.name}' --selector app=httpbin) -o json | jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | base64 --decode | openssl x509 -text -noout | vim -
```

Notice who the issuer is for the httpbin workload that was restarted.

```
Issuer: O = Istio, CN = Intermediate CA, L = myintca
```

If you output the `httpbin` certificate chain

````bash
```bash
istioctl proxy-config secret -n foo deployment/httpbin -o json | jq -r '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' | base64 --decode > httpbin-cert-chain.pem

cat httpbin-cert-chain.pem
````

You will see the new CA cert match on the last certificate.

```
-----BEGIN CERTIFICATE-----
MIIFeDCCA2CgAwIBAgIUPnXzREbd4NJF03hZMc18Qir3+BAwDQYJKoZIhvcNAQEL
BQAwIjEOMAwGA1UECgwFSXN0aW8xEDAOBgNVBAMMB1Jvb3QgQ0EwHhcNMjMwODE4
MTk0NDQ0WhcNMzMwODE1MTk0NDQ0WjA8MQ4wDAYDVQQKDAVJc3RpbzEYMBYGA1UE
AwwPSW50ZXJtZWRpYXRlIENBMRAwDgYDVQQHDAdteWludGNhMIICIjANBgkqhkiG
9w0BAQEFAAOCAg8AMIICCgKCAgEAxZPWUkUiFmh5HEwU10SQAq7TMF1mjek6Zxt7
...
```

### Using istioctl proxy-config tool to easily compare the root CA of each pod

The istioctl binary comes with an array of helpful tools to diagnose the mesh. Up until now we've been manually looking and comparing certificates as to why connectivity isn't working. The istioctl proxy-config option will help streamline this activity.

Without having restarted the `sleep` deployment since the change of the CA in the mesh, let's now use the `rootca-compare` parameter of the istioctl proxy-config command to compare the root CA of both `sleep` and `httpbin` together.

```bash
istioctl proxy-config -n foo rootca-compare $(kubectl get pods -n foo -l app=sleep -o jsonpath='{.items..metadata.name}') $(kubectl get pods -n foo -l app=httpbin -o jsonpath='{.items..metadata.name}')
```

The output should show the connectivity is unavailable.

```
Error: Both [sleep-dcb99444f-h2kw6.foo] and [httpbin-7bb95dc559-nszvr.foo] have the non identical ROOTCA, theoretically the connectivity between them is unavailable
```

Restart the `sleep` app.

```bash
kubectl -n foo rollout restart deployment/sleep

kubectl get po -n foo -l app=sleep
```

Run the istioctl proxy-config rootca-compare command again.

```bash
istioctl proxy-config -n foo rootca-compare $(kubectl get pods -n foo -l app=sleep -o jsonpath='{.items..metadata.name}') $(kubectl get pods -n foo -l app=httpbin -o jsonpath='{.items..metadata.name}')
```

The output should show the connectivity is now available.

```
Both [sleep-856b798fdb-lr6kj.foo] and [httpbin-7bb95dc559-nszvr.foo] have the identical ROOTCA, theoretically the connectivity between them is available
```

You can also verify the app connectivity using the exec command from earlier.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html
```

## Using istioctl proxy-status and proxy-config for mesh diagnostics

To view the overall status of each worklaod proxy in the mesh, you can run the istioctl proxy-status command using the `i` switch to designate the namespace where istiod (control plane) is installed.

```bash
istioctl proxy-status -i aks-istio-system
```

This will output the status of all the istio-proxy (Envoy) services.

```
NAME                             CLUSTER        CDS        LDS        EDS        RDS        ECDS         ISTIOD                              VERSION
httpbin-7bb95dc559-nszvr.foo     Kubernetes     SYNCED     SYNCED     SYNCED     SYNCED     NOT SENT     istiod-asm-1-17-cdb49b9bd-bn5gh     1.17.5-distroless
sleep-856b798fdb-lr6kj.foo       Kubernetes     SYNCED     SYNCED     SYNCED     SYNCED     NOT SENT     istiod-asm-1-17-cdb49b9bd-bn5gh     1.17.5-distroless
```

We can also specifically look at pod and see what listeners and ports are available. This is the listeners information for `httpbin`.

```bash
istioctl proxy-config -n foo listeners $(kubectl get pods -n foo -l app=httpbin -o jsonpath='{.items..metadata.name}')
```

```
ADDRESS      PORT  MATCH                                                                    DESTINATION
10.0.0.10    53    ALL                                                                      Cluster: outbound|53||kube-dns.kube-system.svc.cluster.local
0.0.0.0      80    Trans: raw_buffer; App: http/1.1,h2c                                     Route: 80
0.0.0.0      80    ALL                                                                      PassthroughCluster
10.0.0.1     443   ALL                                                                      Cluster: outbound|443||kubernetes.default.svc.cluster.local
10.0.217.152 443   Trans: raw_buffer; App: http/1.1,h2c                                     Route: metrics-server.kube-system.svc.cluster.local:443
10.0.217.152 443   ALL                                                                      Cluster: outbound|443||metrics-server.kube-system.svc.cluster.local
10.0.96.208  443   ALL                                                                      Cluster: outbound|443||istiod-asm-1-17.aks-istio-system.svc.cluster.local
0.0.0.0      8000  Trans: raw_buffer; App: http/1.1,h2c                                     Route: 8000
0.0.0.0      8000  ALL                                                                      PassthroughCluster
0.0.0.0      15001 ALL                                                                      PassthroughCluster
0.0.0.0      15001 Addr: *:15001                                                            Non-HTTP/Non-TCP
0.0.0.0      15006 Addr: *:15006                                                            Non-HTTP/Non-TCP
0.0.0.0      15006 Trans: tls; App: istio-http/1.0,istio-http/1.1,istio-h2; Addr: 0.0.0.0/0 InboundPassthroughClusterIpv4
0.0.0.0      15006 Trans: tls; Addr: 0.0.0.0/0                                              InboundPassthroughClusterIpv4
0.0.0.0      15006 Trans: tls; Addr: *:80                                                   Cluster: inbound|80||
0.0.0.0      15010 Trans: raw_buffer; App: http/1.1,h2c                                     Route: 15010
0.0.0.0      15010 ALL                                                                      PassthroughCluster
10.0.96.208  15012 ALL                                                                      Cluster: outbound|15012||istiod-asm-1-17.aks-istio-system.svc.cluster.local
0.0.0.0      15014 Trans: raw_buffer; App: http/1.1,h2c                                     Route: 15014
0.0.0.0      15014 ALL                                                                      PassthroughCluster
0.0.0.0      15021 ALL                                                                      Inline Route: /healthz/ready*
0.0.0.0      15090 ALL                                                                      Inline Route: /stats/prometheus*
```

You can also look at the routing information from the istio-proxy for the pod. Again we will look at `httpbin`.

```bash
istioctl proxy-config -n foo route $(kubectl get pods -n foo -l app=httpbin -o jsonpath='{.items..metadata.name}')
```

```
NAME                                                 VHOST NAME                                                   DOMAINS                                           MATCH                  VIRTUAL SERVICE
80                                                   sleep.foo.svc.cluster.local:80                               sleep, sleep.foo + 1 more...                      /*
8000                                                 httpbin.foo.svc.cluster.local:8000                           httpbin, httpbin.foo + 1 more...                  /*
metrics-server.kube-system.svc.cluster.local:443     metrics-server.kube-system.svc.cluster.local:443             *                                                 /*
15010                                                istiod-asm-1-17.aks-istio-system.svc.cluster.local:15010     istiod-asm-1-17.aks-istio-system, 10.0.96.208     /*
15014                                                istiod-asm-1-17.aks-istio-system.svc.cluster.local:15014     istiod-asm-1-17.aks-istio-system, 10.0.96.208     /*
inbound|80||                                         inbound|http|8000                                            *                                                 /*
                                                     backend                                                      *                                                 /stats/prometheus*
InboundPassthroughClusterIpv4                        inbound|http|0                                               *                                                 /*
                                                     backend                                                      *                                                 /healthz/ready*
```

## A Quick Look at Istio Authorization Policies

As of now the only mesh security in the module has been centered around matching CA certificates. If the CA certificates matched, authorizing the mTLS connection, traffic was able to flow between the `sleep` and `httpbin` applications. We will now quickly discuss how Istio's [Authorization Policies](https://istio.io/latest/docs/reference/config/security/authorization-policy/) can be applied, in addition to having mTLS, as a way to have finer grain controls of the type of traffic and operation you want to authorize for each workload.

Authorization policies will allow you to ALLOW/DENY traffic by using a combination of several attributes to craft an authorization policy specific to your application needs. Examples can be to only allow a specific service, using a specific http operation, to a specific L7 path.

There have been two endpoints we have been using to test connectivity between the `sleep` and `httpbin` applications. They have been both the `html` and `headers` path. We will now setup an authorization policy that will only allow the `html` path to be reached. Attemts to the `headers` path will be denied by the istio-proxy.

Deploy the `html` only authorization policy for `httpbin`.

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: foo
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/foo/sa/sleep"]
    - source:
        namespaces: ["foo"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/html"]
EOF
```

Test connectivity from `sleep` to `httpbin` for both `html` and `headers` path.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/html

kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/headers
```

The `html` path should work as normal, but the `headers` path returns the and RBAC access denied error.

```
RBAC: access denied
```

Even through both applications are managed by the same mesh, we can put access control from all workloads in the mesh on the cluster.

We can authorize the headers path by adding heders to the paths array.

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: foo
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/foo/sa/sleep"]
    - source:
        namespaces: ["foo"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/html", "/headers"]
EOF
```

You should now be able to receive a response from the `httpbin` `headers` path.

```bash
kubectl exec -it -n foo deploy/sleep -c sleep -- curl -sS http://httpbin.foo:8000/headers
```

```
{
  "headers": {
    "Accept": "*/*",
    "Host": "httpbin.foo:8000",
    "User-Agent": "curl/8.2.1",
    "X-B3-Parentspanid": "4933c3939d7cd771",
    "X-B3-Sampled": "0",
    "X-B3-Spanid": "1b423362f6985389",
    "X-B3-Traceid": "15ed8d348e8b975f4933c3939d7cd771",
    "X-Envoy-Attempt-Count": "1",
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/foo/sa/httpbin;Hash=910321a05db944b691abb1e9bc00db150de0f806f4a20c55f50c91450b342b0f;Subject=\"\";URI=spiffe://cluster.local/ns/foo/sa/sleep"
  }
}
```
