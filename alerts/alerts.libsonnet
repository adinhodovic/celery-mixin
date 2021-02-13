{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-resources',
        rules: [
          {
            alert: 'KubeNodeNotReady',
            expr: |||
              kube_node_status_condition{%(kubeStateMetricsSelector)s,condition="Ready",status="true"} == 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Overcommited CPU resource requests on Pods, cannot tolerate node failure.',
            },
            'for': '1h',
          },
        ],
      },
    ],
  },
}
