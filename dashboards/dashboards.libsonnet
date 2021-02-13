local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local g = import 'github.com/grafana/jsonnet-libs/grafana-builder/grafana.libsonnet';
local template = grafana.template;
local statPanel = grafana.statPanel;
local row = grafana.row;

{
  grafanaDashboards+:: {

    local taskTemplate =
      template.new(
        name='task',
        datasource='$datasource',
        query='label_values(task_sent_total, name)',
        current='',
        hide='',
        refresh=1,
        includeAll=false,
        sort=1
      ),

    local taskFailedQuery = |||
      sum by (name) (increase(celery_task_failed_total{%(celerySelector)s, name="$task"}[10m]))
    ||| % $._config,

    local taskSucceededQuery = std.strReplace(taskFailedQuery, 'failed', 'succeeded'),
    local taskReceivedQuery = std.strReplace(taskFailedQuery, 'failed', 'received'),
    local taskRetriedQuery = std.strReplace(taskFailedQuery, 'failed', 'retried'),
    local taskRevokedQuery = std.strReplace(taskFailedQuery, 'failed', 'revoked'),
    local taskRejectedQuery = std.strReplace(taskFailedQuery, 'failed', 'rejected'),

    local taskFailedQuery1d = |||
      sum(increase(celery_task_failed_total{%(celerySelector)s}[1d]))
    ||| % $._config,
    local taskSucceededQuery1d = std.strReplace(taskFailedQuery1d, 'failed', 'succeeded'),
    local taskReceivedQuery1d = std.strReplace(taskFailedQuery1d, 'failed', 'received'),

    local successRate1d = |||
      %s/(%s+%s)
    ||| % [taskSucceededQuery1d, taskSucceededQuery1d, taskFailedQuery1d],
    local successRateTask1d = std.strReplace(successRate1d, 'sum', 'sum by (name)'),

    'celery.json':
      grafana.dashboard.new(
        'Celery',
        uid='123'
      )
      .addTemplate(
        {
          current: {
            text: 'default',
            value: 'default',
          },
          hide: 0,
          label: null,
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: '',
          type: 'datasource',
        },
      )
      .addRow(
        row.new('Summary')
        .addPanel(
          statPanel.new(
            'Celery Workers',
            datasource='$datasource',
          )
          .addTarget(grafana.prometheus.target('count(celery_worker_up)')),
          gridPos={ h: 4, w: 6, x: 0, y: 1 }
        )
        .addPanel(
          statPanel.new(
            'Tasks received by brokers last 24h',
            datasource='$datasource',
          )
          .addTarget(grafana.prometheus.target(taskReceivedQuery1d)),
          gridPos={ h: 4, w: 6, x: 6, y: 1 }
        )
        .addPanel(
          statPanel.new(
            'Successful completion rate last 24h',
            datasource='$datasource',
            unit='percentunit'
          )
          .addTarget(grafana.prometheus.target(successRate1d))
          .addThreshold({ color: 'green', value: 0.95 }),
          gridPos={ h: 4, w: 6, x: 12, y: 1 }
        )
        .addPanel(
          grafana.tablePanel.new(
            'Task Stats',
            datasource='$datasource',
            span='6',
            columns=['name'],
            styles=[
              {
                alias: 'Time',
                dateFormat: 'YYYY-MM-DD HH:mm:ss',
                type: 'hidden',
                pattern: 'Time',
              },
              {
                alias: 'Task',
                pattern: 'name',
              },
              {
                alias: 'Success Rate',
                pattern: 'Value',
                type: 'number',
                unit: 'percentunit',
              },
            ]
          )
          .addTarget(grafana.prometheus.target(successRateTask1d, format='table', instant=true)),
          gridPos={ h: 1, w: 24, x: 0, y: 0 }
        )
      )
      .addRow(
        row.new('Individual Tasks')
        .addPanel(
          g.panel(
            '$task',
          ) +
          g.queryPanel(
            [
              taskSucceededQuery,
              taskFailedQuery,
              taskRetriedQuery,
              taskRejectedQuery,
              taskRevokedQuery,
            ],
            [
              'Succeeded',
              'Failed',
              'Retried',
              'Rejected',
              'Revoked',
            ]
          )
        )
      ) + { templating+: { list+: [taskTemplate] }, gridPos: { w: 12 } },
  },
}
