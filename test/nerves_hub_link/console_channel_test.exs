defmodule NervesHubLink.ConsoleChannelTest do
  use ExUnit.Case, async: false
  alias NervesHubLink.{ClientMock, ConsoleChannel}
  alias PhoenixClient.Message

  doctest ConsoleChannel

  setup context do
    context = Map.put(context, :state, %ConsoleChannel.State{})
    :ok = Application.ensure_started(:iex)
    Application.put_env(:nerves_hub_link, :remote_iex, true)
    Mox.verify_on_exit!(context)
    context
  end

  describe "handle_info - Channel Messages" do
    test "restart IEx process", %{state: state} do
      {:ok, iex_pid} = ExTTY.start_link(type: :elixir, name: Test)
      state = %{state | iex_pid: iex_pid}
      Process.unlink(iex_pid)
      message = %Message{event: "restart"}

      {:noreply, new_state} = ConsoleChannel.handle_info(message, state)
      assert new_state.iex_pid != state.iex_pid
    end

    test "dn - sends text to ExTTY", %{state: state} do
      {:ok, iex_pid} = ExTTY.start_link(handler: self(), type: :elixir)
      state = %{state | iex_pid: iex_pid}
      data = "Howdy\r\n"
      msg = %Message{event: "dn", payload: %{"data" => data}}

      assert {:noreply, state} == ConsoleChannel.handle_info(msg, state)
      assert_receive {:tty_data, "\e[33m\e[36mHowdy\e[0m\e[33m\e[0m\r\n"}
    end

    test "phx_error - attempts rejoin", %{state: state} do
      Mox.expect(ClientMock, :handle_error, fn _ -> :ok end)
      msg = %Message{event: "phx_error", payload: %{}}
      assert ConsoleChannel.handle_info(msg, state) == {:noreply, state}
      assert_receive :join
    end

    test "phx_close - attempts rejoin", %{state: state} do
      Mox.expect(ClientMock, :handle_error, fn _ -> :ok end)
      msg = %Message{event: "phx_close", payload: %{}}
      assert ConsoleChannel.handle_info(msg, state) == {:noreply, state}
      assert_receive :join
    end
  end

  test "reports unknown handle_info message" do
    Mox.expect(ClientMock, :handle_error, 2, fn _ -> :ok end)
    assert ConsoleChannel.handle_info(:wat, %{}) == {:noreply, %{}}
    assert ConsoleChannel.handle_info(%Message{event: "wat"}, %{}) == {:noreply, %{}}
  end
end
