defmodule Citadel.CredentialLeaseTest do
  use ExUnit.Case, async: true

  alias Citadel.ConnectorBinding.CredentialLease

  test "materializes credential leases for every generic binding kind without provider branching" do
    for binding_kind <- CredentialLease.binding_kinds() do
      assert {:ok, lease} =
               CredentialLease.materialize(
                 binding_kind,
                 lease_attrs(binding_kind)
               )

      assert lease.binding_kind == binding_kind
      assert lease.binding_ref == "binding://tenant/#{binding_kind}/primary"
      assert lease.credential_scope_ref == "credential-scope://tenant/#{binding_kind}/primary"
      assert lease.required_scopes == ["scope:read"]
      assert lease.raw_material_present? == false
    end
  end

  test "rejects raw credential material and unsupported binding kinds" do
    assert {:error, {:raw_credential_material, [:token]}} =
             CredentialLease.materialize(
               :runtime,
               lease_attrs(:runtime) |> Map.put(:token, "secret")
             )

    assert {:error, {:unsupported_binding_kind, :provider_family}} =
             CredentialLease.materialize(:provider_family, lease_attrs(:runtime))
  end

  test "rejects credential scope widening" do
    assert {:error, {:credential_scope_mismatch, [:credential_scope_ref]}} =
             CredentialLease.materialize(
               :tool,
               lease_attrs(:tool),
               expected_credential_scope_ref: "credential-scope://tenant/tool/other"
             )

    assert {:error, {:required_scope_not_allowed, ["scope:write"]}} =
             CredentialLease.materialize(
               :tool,
               lease_attrs(:tool) |> Map.put(:required_scopes, ["scope:read", "scope:write"]),
               allowed_required_scopes: ["scope:read"]
             )
  end

  defp lease_attrs(binding_kind) do
    %{
      tenant_ref: "tenant://acme",
      installation_ref: "installation://acme/extravaganza",
      binding_ref: "binding://tenant/#{binding_kind}/primary",
      credential_scope_ref: "credential-scope://tenant/#{binding_kind}/primary",
      connector_binding_ref: "connector-binding://tenant/#{binding_kind}/primary",
      credential_handle_ref: "credential-handle://tenant/#{binding_kind}/primary",
      credential_lease_ref: "credential-lease://tenant/#{binding_kind}/primary/1",
      operation_class: :source_read,
      required_scopes: ["scope:read"],
      issued_at: ~U[2026-05-17 00:00:00Z],
      expires_at: ~U[2026-05-17 00:05:00Z],
      metadata: %{"provider_family" => "fixture"}
    }
  end
end
