defmodule ExLinkHeader do

  @moduledoc """
  HTTP link header parser
  """

  def parse("") do
    %{}
  end

  def parse(nil) do
    %{}
  end

  def parse(link_header) do
    links = String.split(link_header, ", ")

    parse_links(links)
  end

  defp parse_links(links) do

    parsed_links = Enum.map(links, fn link ->
        [_, url, name] = Regex.run(~r{<([^>]+)>; rel="?([a-z]+)"?}, link)
        page = case Regex.run(~r{.+[\?|\&]page=(\d+)\??}, url) do
          [_, page] -> page
          nil -> nil
        end

        per_page = case Regex.run(~r{.+[\?|\&]per_page=(\d+)\??}, url) do
          [_, per_page] -> per_page
          nil -> nil
        end

        {name, %{ url: url, page: page, per_page: per_page }}
      end)

    parsed_links
    |> Enum.into(%{})
  end

end