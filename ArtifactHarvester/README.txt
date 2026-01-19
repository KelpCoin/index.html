Artifact Harvester Sidecar

Quickstart
- Run bootstrap: powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
- Run scan: ArtifactHarvester.exe scan --full
- Run watch: ArtifactHarvester.exe watch
- Export: ArtifactHarvester.exe export
- Health: ArtifactHarvester.exe health

Outputs
- <SidecarHome>\out\index.sqlite
- <SidecarHome>\out\index.json
- <SidecarHome>\out\index.csv
- <SidecarHome>\out\per_artifact\<artifact_id>\eval.json

Logs
- <SidecarHome>\logs\ArtifactHarvester.log
- <SidecarHome>\logs\errors.log

Verification steps
1) Run ArtifactHarvester.exe scan --full
2) Confirm index.csv and index.json exist
3) Check logs for processed files
