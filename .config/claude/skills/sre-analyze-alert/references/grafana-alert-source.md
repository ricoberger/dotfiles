# Grafana Alert Source

Use this reference when only the Grafana alert source is provided in the format
`<grafana-url>/alerting/grafana/<alert-id>/view` (e.g.,
`https://grafana.example.com/alerting/grafana/alert-kubenodeeviction/view`).

## Grafana Instance

Use the `GRAFANA_INSTANCES` environment variable to get the correct Grafana url
and the credentials for the Grafana API access. If you are not sure which
instance to use, show a list of available instances and ask the user to select
one.

## Alert Details

Use the Grafana API to get the details of the alert. The relevant API endpoint
is:

```bash
curl -sS -H "Authorization: $TOKEN" \
  -X GET "$GRAFANA/api/ruler/grafana/api/v1/rule/$ALERTID"
```

The response looks like this:

```json
{
  "labels": {},
  "annotations": {},
  "grafana_alert": {
    "title": "<alert-name>",
    "data": [],
    "uid": "<alert-id>",
    "namespace_uid": "<folder-uid>",
    "rule_group": "<rule-group>"
  }
}
```

Use the details from the response to get the actual alerts:

```bash
curl -sS -H "Authorization: $TOKEN" \
  -X GET "$GRAFANA/api/prometheus/grafana/api/v1/rules?rule_group=<rule-group>&rule_group[]=<rule-group>&rule_name=<alert-name>&rule_name[]=<alert-name>&folder_uid=<folder-uid>"
```

The response contains a list of all the alerts in the
`data.groups[].rules[].alerts` field:

```json
{
  "status": "success",
  "data": {
    "groups": [
      {
        "name": "<rule-group>",
        "folderUid": "<folder-uid>",
        "rules": [
          {
            "alerts": [
              {
                "labels": {
                  "__name__": "",
                  "alertname": "",
                  "severity": "",
                  "<more-labels>": "..."
                },
                "annotations": {
                  "__dashboardUid__": "",
                  "__panelId__": "",
                  "description": "",
                  "runbook_url": "",
                  "summary": ""
                  "<more-annotations>": "..."
                },
                "state": "",
                "activeAt": "",
                "value": ""
              }
            ],
            "uid": "<alert-id>",
            "folderUid": "<folder-uid>"
          }
        ]
      }
    ]
  }
}
```

Show the user a list of all active alerts
(`jq '[.data.groups[].rules[].alerts[]]'`) and let them select the one they want
to investigate. Use the `labels` field to provide more context about each alert
in the list. Once the user selects an alert, use its details to start the
investigation in the `sre-analyze-alert` skill.
