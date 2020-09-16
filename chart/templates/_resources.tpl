{{- /*
==========================================================================================
| _resources.update $
+-----------------------------------------------------------------------------------------
| Create an entry in $.Values.resources for each instance group in $Values.jobs
| (if it doesn't already exist), and each job in the group (again, if it doesn't
| already exist).  The config/resources.yaml file can override the groups and jobs.
| As part of this it also adds missing '$defaults' keys, and uses '$defaults' to
| resolve missing values.
==========================================================================================
*/}}
{{- define "_resources.update" }}
  {{- include "_resources.expandDefaults" (list $.Values.resources "$defaults") }}

  {{- /* Fill missing resources entries with data from jobs tree. */}}
  {{- range $jobs_ig_name, $jobs_ig := $.Values.jobs }}
    {{- include "_resources.expandDefaults" (list $.Values.resources $jobs_ig_name) }}

    {{- $resources_ig := index $.Values.resources $jobs_ig_name }}
    {{- range $job_name, $jobs_job := $jobs_ig }}
      {{- include "_resources.expandDefaults" (list $resources_ig $job_name) }}

      {{- $resources_job := index $resources_ig $job_name }}
      {{- range $process_name := $jobs_job.processes }}
        {{- include "_resources.expandDefaults" (list $resources_job $process_name) }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- $global_defaults := index $.Values.resources "$defaults" }}
  {{- $_ := unset $.Values.resources "$defaults" }}

  {{- /* Verify that each entry in the 'resources' tree also has a 'jobs' entry */}}
  {{- range $ig_name, $ig := $.Values.resources }}
    {{- if not (hasKey $.Values.jobs $ig_name) }}
      {{- include "_config.fail" (printf "Instance group %q defined in resources but not in jobs" $ig_name) }}
    {{- end }}

    {{- $jobs_ig := index $.Values.jobs $ig_name }}
    {{- $ig_defaults := index $ig "$defaults" }}
    {{- $_ := unset $ig "$defaults" }}

    {{- range $job_name, $job := $ig }}
      {{- if not (hasKey $jobs_ig $job_name) }}
        {{- include "_config.fail" (printf "Instance group %q job %q defined in resources but not in jobs" $ig_name $job_name) }}
      {{- end }}

      {{- $jobs_job := index $jobs_ig $job_name }}
      {{- $job_defaults := index $job "$defaults" }}
      {{- $_ := unset $job "$defaults" }}

      {{- range $process_name, $process := $job }}
        {{- if not (has $process_name $jobs_job.processes) }}
          {{- include "_config.fail" (printf "Instance group %q job %q process %q defined in resources but not in jobs" $ig_name $job_name $process_name) }}
        {{- end }}

        {{- $process_defaults := index $process "$defaults" }}
        {{- $_ := unset $process "$defaults" }}

        {{- $merged := merge $process $process_defaults $job_defaults $ig_defaults $global_defaults }}

        {{- /* Default request is limit/4, but at least 32, and never more than limit */}}
        {{- if and $merged.memory.limit (not $merged.memory.request) }}
          {{- $_ := set $merged.memory "request" ((div $merged.memory.limit 4) | max 32 | min $merged.memory.limit | int) }}
        {{- end }}

        {{- /* Update resource settings in-place */}}
        {{- range $key, $value := $merged }}
          {{- $_ := set $process $key $value }}
        {{- end }}
      {{- end }}

      {{- if not (index $.Values.jobs $ig_name $job_name "condition") }}
        {{- $_ := unset $ig $job_name }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- /*
==========================================================================================
| _resources.expandDefaults (list $dict $key)
+-----------------------------------------------------------------------------------------
| XXX
==========================================================================================
*/}}
{{- define "_resources.expandDefaults" }}
  {{- $dict := index . 0 }}
  {{- $key := index . 1 }}

  {{- if not (hasKey $dict $key) }}
    {{- $_ := set $dict $key dict }}
  {{- end }}
  {{- $value := index $dict $key }}

  {{- $defaults := dict "memory" (dict "limit" nil "request" nil) }}
  {{- if kindIs "map" $value }}
    {{- if not (hasKey $value "$defaults") }}
      {{- $_ := set $value "$defaults" $defaults }}
    {{- else if not (kindIs "map" (index $value "$defaults")) }}
      {{- include "_resources.expandDefaults" (list $value "$defaults") }}
    {{- end }}
  {{- else }}
    {{- $_ := set $defaults.memory "limit" $value }}
    {{- if eq $key "$defaults" }}
      {{- $_ := set $dict $key $defaults }}
    {{- else }}
      {{- $_ := set $dict $key (dict "$defaults" $defaults) }}
    {{- end }}
  {{- end }}
{{- end }}
