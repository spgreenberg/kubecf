{{- /*
==========================================================================================
| _resources.update $
+-----------------------------------------------------------------------------------------
| Create an entry in $.Values.resources for each instance group in $Values.jobs
| (if it doesn't already exist), and each job in the group (again, if it doesn't
| already exist).  The config/resources.yaml file can override the groups and jobs.
| As part of this it also adds missing '$default' keys, and uses '$default' to
| resolve missing values.
==========================================================================================
*/}}
{{- define "_resources.update" }}
  {{- /* Phase I - Fill missing entries with data from jobs */}}
  {{- /* Iterate the groups */}}
  {{- range $jigname, $jig := $.Values.jobs }}
    {{- /* Groups missing under `resources` are added, with a default */}}
    {{- if not (hasKey $.Values.resources $jigname) }}
      {{- $_ := set $.Values.resources $jigname (dict "$default" "2Gi") }}
    {{- end }}
    {{- $ig := index $.Values.resources $jigname }}
    {{- /* Groups without a default get one */}}
    {{- if not (hasKey $ig "$default") }}
      {{- $_ := set $ig "$default" "2Gi" }}
    {{- end }}
    {{- /* Iterate jobs of the group (in jobs) */}}
    {{- range $jjobname, $jjob := $jig }}
      {{- /* Job missing in group is added, with nil value (to use fallback) */}}
      {{- if not (hasKey $ig $jjobname) }}
        {{- $_ := set $ig $jjobname nil }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- /* Phase II - Resolve nil values to defaults */}}
  {{- /* Iterate the groups (in memory) */}}
  {{- range $igname, $ig := $.Values.resources }}
    {{- /* Get the fallback condition */}}
    {{- $default := index $ig "$default" }}
    {{- $_ := unset $ig "$default" }}
    {{- /* Iterate the jobs */}}
    {{- range $jobname, $jobvalue := $ig }}
      {{- if not (include "_config.lookup" (list $ "jobs" $igname $jobname)) }}
        {{- include "_config.fail" (printf "Job %q in instance group %q does not exist" $jobname $igname) }}
      {{- end }}
      {{- if index $.Values.jobs $igname $jobname "condition" }}
        {{- /* For active jobs, resolve missing (nil) values to the fallback value */}}
        {{- if kindIs "invalid" $jobvalue }}
          {{- $_ := set $ig $jobname $default }}
        {{- end }}
      {{- else }}
        {{- /* Drop inactive jobs from memory, as per the job's condition */}}
        {{- $_ := unset (index $.Values.resources $igname) $jobname }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}