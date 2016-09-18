defmodule ElexirTest do
  use ExUnit.Case

  @moduletag :integrated

  import Elexir

  test "generates pattern from line" do
    string = "access-list outside-ingress extended permit icmp any any log"

    assert generate_patterns(string, 0) ==
      [~r/^access-list outside-ingress extended permit icmp any any log$/]
  end

  test "generates pattern from another line" do
    string = "access-list outside-ingress extended permit tcp any object AnObject eq https log"

    assert generate_patterns(string, 0) ==
      [~r/^access-list outside-ingress extended permit tcp any object AnObject eq https log$/]
  end

  test "generates patterns for multiple lines" do
    string =
      """
      access-list outside-ingress extended permit icmp any any log
      access-list outside-ingress extended permit tcp any object AnObject eq https log
      """

    assert generate_patterns(string, 0.06) ==
      [ ~r/^access-list outside-ingress extended permit \S+ any \S+ \S+ \S+ \S+ log$/,
        ~r/^access-list outside-ingress extended permit \S+ any \S+ log$/,
      ]
  end

  test "generates patterns for multiple lines with a different threshold" do
    string =
      """
      access-list outside-ingress extended permit icmp any any log
      access-list outside-ingress extended permit tcp any object AnObject eq https log
      """

    assert generate_patterns(string, 0.12) == []
  end

  test "generates patterns for multiple lines with threshold at maximum" do
    string =
      """
      access-list outside-ingress extended permit icmp any any log
      access-list outside-ingress extended permit tcp any object AnObject eq https log
      """

    assert generate_patterns(string, 1) == []
  end
end
