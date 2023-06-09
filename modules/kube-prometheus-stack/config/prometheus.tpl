prometheus:
  prometheusSpec:
    thanos:
       secretProviderClass:
         provider: aws
         parameters:
           objects: |
             - objectName: ${thanos_sidecar_secret_name}
               objectType: "secretsmanager"
               objectAlias: "object-store.yaml"
       objectStorageConfigFile: /mnt/secrets/object-store.yaml
       volumeMounts:
         - name: thanos-config
           mountPath: /mnt/secrets
           readOnly: true
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp2
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
    volumes:
    - name: thanos-config
      csi: 
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "prometheus-kube-prometheus-prometheus"
    