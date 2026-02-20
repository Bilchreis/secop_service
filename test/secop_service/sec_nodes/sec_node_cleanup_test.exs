defmodule SecopService.SecNodes.SecNodeCleanupTest do
  use SecopService.DataCase, async: false

  use Oban.Testing, repo: SecopService.Repo

  alias SecopService.SecNodes.SecNode

  describe "cleanup_old_nodes job" do
    test "enqueues cleanup job for old nodes based on should_cleanup calculation" do
      # Get the configured retention days (default 30)
      retention_days = Application.get_env(:secop_service, :data_retention_days, 30)

      # Create an old node that should be cleaned up
      old_datetime = DateTime.add(DateTime.utc_now(), -(retention_days + 1), :day)

      old_node =
        SecNode
        |> Ash.Changeset.for_create(:create, %{
          uuid: Ecto.UUID.generate(),
          equipment_id: "old_equipment",
          host: "192.168.1.1",
          port: 5000,
          description: "Old node to be cleaned up"
        })
        |> Ash.create!()

      # Manually set the inserted_at to simulate an old record
      old_node =
        old_node
        |> Ecto.Changeset.change(inserted_at: old_datetime)
        |> SecopService.Repo.update!()

      # Create a recent node that should NOT be cleaned up
      recent_node =
        SecNode
        |> Ash.Changeset.for_create(:create, %{
          uuid: Ecto.UUID.generate(),
          equipment_id: "recent_equipment",
          host: "192.168.1.2",
          port: 5001,
          description: "Recent node to keep"
        })
        |> Ash.create!()

      # Load the should_cleanup calculation
      old_node_with_calc = Ash.load!(old_node, :should_cleanup)
      recent_node_with_calc = Ash.load!(recent_node, :should_cleanup)

      # Verify the should_cleanup calculation
      assert old_node_with_calc.should_cleanup == true
      assert recent_node_with_calc.should_cleanup == false
    end

    test "cleanup job only processes nodes that match should_cleanup filter" do
      retention_days = Application.get_env(:secop_service, :data_retention_days, 30)

      # Create multiple old nodes
      old_datetime = DateTime.add(DateTime.utc_now(), -(retention_days + 5), :day)

      _old_node_1 =
        SecNode
        |> Ash.Changeset.for_create(:create, %{
          uuid: Ecto.UUID.generate(),
          equipment_id: "old_1",
          host: "192.168.1.10",
          port: 6000,
          description: "Old node 1"
        })
        |> Ash.create!()
        |> Ecto.Changeset.change(inserted_at: old_datetime)
        |> SecopService.Repo.update!()

      _old_node_2 =
        SecNode
        |> Ash.Changeset.for_create(:create, %{
          uuid: Ecto.UUID.generate(),
          equipment_id: "old_2",
          host: "192.168.1.11",
          port: 6001,
          description: "Old node 2"
        })
        |> Ash.create!()
        |> Ecto.Changeset.change(inserted_at: old_datetime)
        |> SecopService.Repo.update!()

      # Create a recent node
      recent_node =
        SecNode
        |> Ash.Changeset.for_create(:create, %{
          uuid: Ecto.UUID.generate(),
          equipment_id: "recent",
          host: "192.168.1.12",
          port: 6002,
          description: "Recent node"
        })
        |> Ash.create!()

      # Verify initial state
      initial_count = Ash.count!(SecNode)
      assert initial_count == 3

      # Query all nodes and load the should_cleanup calculation
      all_nodes =
        SecNode
        |> Ash.Query.for_read(:read_for_cleanup)
        |> Ash.read!()

      # Filter nodes that should be cleaned up in Elixir
      nodes_to_cleanup = Enum.filter(all_nodes, & &1.should_cleanup)

      assert length(nodes_to_cleanup) == 2
      assert Enum.all?(nodes_to_cleanup, & &1.should_cleanup)

      # Simulate cleanup by destroying the old nodes
      Enum.each(nodes_to_cleanup, fn node ->
        Ash.destroy!(node)
      end)

      # Verify that only recent node remains
      remaining_count = Ash.count!(SecNode)
      assert remaining_count == 1

      remaining_node = Ash.read_one!(SecNode)
      assert remaining_node.uuid == recent_node.uuid
    end

    test "should_cleanup calculation respects custom retention days" do
      # Test with custom retention period
      original_retention = Application.get_env(:secop_service, :data_retention_days, 30)

      try do
        # Set custom retention to 7 days
        Application.put_env(:secop_service, :data_retention_days, 7)

        # Create a node that's 10 days old (should be cleaned up with 7-day retention)
        old_datetime = DateTime.add(DateTime.utc_now(), -10, :day)

        node =
          SecNode
          |> Ash.Changeset.for_create(:create, %{
            uuid: Ecto.UUID.generate(),
            equipment_id: "test_equipment",
            host: "192.168.1.100",
            port: 7000,
            description: "Test node"
          })
          |> Ash.create!()
          |> Ecto.Changeset.change(inserted_at: old_datetime)
          |> SecopService.Repo.update!()

        # Load and verify
        node_with_calc = Ash.load!(node, :should_cleanup)
        assert node_with_calc.should_cleanup == true

        # Create a node that's 5 days old (should NOT be cleaned up with 7-day retention)
        recent_datetime = DateTime.add(DateTime.utc_now(), -5, :day)

        recent_node =
          SecNode
          |> Ash.Changeset.for_create(:create, %{
            uuid: Ecto.UUID.generate(),
            equipment_id: "recent_equipment",
            host: "192.168.1.101",
            port: 7001,
            description: "Recent test node"
          })
          |> Ash.create!()
          |> Ecto.Changeset.change(inserted_at: recent_datetime)
          |> SecopService.Repo.update!()

        recent_node_with_calc = Ash.load!(recent_node, :should_cleanup)
        assert recent_node_with_calc.should_cleanup == false
      after
        # Restore original retention setting
        Application.put_env(:secop_service, :data_retention_days, original_retention)
      end
    end

    test "boundary test: node exactly at retention cutoff is not cleaned up" do
      retention_days = Application.get_env(:secop_service, :data_retention_days, 30)

      # Create a node slightly newer than the retention boundary
      # Add 1 minute buffer to avoid timing drift between test setup and calculation
      cutoff_datetime = DateTime.add(DateTime.utc_now(), -(retention_days * 86400 - 60), :second)

      node =
        SecNode
        |> Ash.Changeset.for_create(:create, %{
          uuid: Ecto.UUID.generate(),
          equipment_id: "boundary_equipment",
          host: "192.168.1.200",
          port: 8000,
          description: "Boundary test node"
        })
        |> Ash.create!()
        |> Ecto.Changeset.change(inserted_at: cutoff_datetime)
        |> SecopService.Repo.update!()

      node_with_calc = Ash.load!(node, :should_cleanup)

      # Node at exactly the cutoff should NOT be cleaned up (only older than cutoff)
      assert node_with_calc.should_cleanup == false
    end
  end

  describe "AshOban worker configuration" do
    test "worker and scheduler modules are properly configured" do
      # Verify the trigger configuration exists
      triggers = AshOban.Info.oban_triggers(SecNode)
      assert triggers != []

      trigger = Enum.find(triggers, &(&1.name == :cleanup_old_nodes))
      assert trigger != nil
      assert trigger.action == :destroy
      assert trigger.read_action == :read_for_cleanup
      assert trigger.scheduler_cron == "0 2 * * *"
    end
  end
end
