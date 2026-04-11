# Jido Integration V2 Contracts

This workspace package vendors the higher-order `Jido.Integration.V2` contract
slice that Citadel publishes today:

- `SubjectRef`
- `EvidenceRef`
- `GovernanceRef`
- `ReviewProjection`
- `DerivedStateAttachment`

The package exists so the welded `citadel` Hex artifact remains self-contained
and publishable even while the wider upstream contracts package is not yet
available as a Hex dependency.
