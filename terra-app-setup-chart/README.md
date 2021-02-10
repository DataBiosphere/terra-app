# Install terra-set-up chart
```
helm install  --set serviceAccount.annotations.gcpServiceAccount="qi-leo-restart-apache@broad-dsde-dev.iam.gserviceaccount.com" -n qi-test qi-set-up-test ./terra-app-setup-chart
```


```
kubectl describe serviceaccounts/leonardo-app-ksa -n qi-test                                                                                               [21/02/8| 3:06PM]
Name:                leonardo-app-ksa
Namespace:           qi-test
Labels:              app.kubernetes.io/managed-by=Helm
                     leonardo=true
Annotations:         iam.gke.io/gcp-service-account: qi-leo-restart-apache@broad-dsde-dev.iam.gserviceaccount.com
                     meta.helm.sh/release-name: qi-set-up-test
                     meta.helm.sh/release-namespace: qi-test
Image pull secrets:  <none>
Mountable secrets:   leonardo-app-ksa-token-7m2m8
Tokens:              leonardo-app-ksa-token-7m2m8
Events:              <none>
```


# Publish Chart
At project root, run the following commands

```
helm package terra-app-setup-chart
mkdir terra-app-setup-chart/repo
mv terra-app-setup-0.0.1.tgz terra-app-setup-chart/repo
helm repo index terra-app-setup-chart/repo/ --url https://storage.googleapis.com/terra-app-setup-chart
gsutil rsync -d terra-app-setup-chart/repo gs://terra-app-setup-chart 
```