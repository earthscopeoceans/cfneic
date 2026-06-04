# Repository Notes

## Working Goals

1. Update the legacy Fortran workflow for expanded input text files, especially newer `geo_DET.csv` layouts.
2. Streamline the run process so data files do not have to be copied manually into a new working directory.
3. Consider downstream packaging only after the Fortran workflow is stable. The likely direction is not a Python wrapper around this code, but a separate package that further curates and exposes the outputs produced here.

## Guardrails

- Keep early changes small, auditable, and behavior-preserving against the current successful run products in `/Users/jdsimon/mermaid/cfneic`.
- Do not delete generated files, rename files, or create packaging until that work is explicitly requested.
- Treat the current Fortran outputs as regression references while modernizing the parser and run orchestration.

## AGENT instructions
- Suggest when to start a new thread to save tokens as context grows.
- When a coherent work unit is complete, tell the user it is a good commit point
  and suggest a concise commit message. Use a plain, sensible, capitalized
  message rather than a `<type>: message` convention.
- Any time you suggest a commit message, also bump version (`major`, `minor`, or
  `patch`) and alert user
  
