defmodule ExLinkHeader.Parser do

  alias ExLinkHeader.ParseError
  require ExLinkHeaderEntry

  @moduledoc """
  HTTP link header parser
  """

  @regex_format ~r{<?(.+)>; (.+)}

  def parse(header, defaults \\ %{})
  def parse("", _defaults), do: :error
  def parse(nil, _defaults), do: :error
  def parse(link_header, defaults), do: parse_links(link_header, defaults)

  def parse!(link_header, defaults \\ %{}) do
    case parse(link_header, defaults) do
      {:ok, result} -> result
      :error -> raise ParseError, "Parse error: no valid links to parse"
    end
  end

  defp extract(links) do
    links
    |> Enum.filter(fn(link) ->
      Regex.match?(@regex_format, link)
    end)
    |> Enum.map(fn(link) ->
      [_, url, params] = Regex.run(@regex_format, link)
      {url, parse_params(params)}
    end)
  end

  defp extract_relationships(links) when links == [], do: nil
  defp extract_relationships(links) do
    links
    |> Enum.flat_map(fn(link) ->
        {url, params} = link
        %{rel: rels} = params

        rels
        |> String.split(" ", trim: true)
        |> Enum.map(fn(rel) ->
            {url, Map.merge(params, %{rel: rel})}
          end)
      end)
  end

  defp extract_and_parse_query(url, defaults) do
    extracted_query = Regex.run(~r{.+\?(.+)}, url)

    extracted_query
    |> parse_query(defaults)
  end

  defp filter(nil), do: nil
  defp filter(links) do
    Enum.filter(links, fn(link) ->
      {url, params} = link
      valid_url?(url) && has_rel?(params)
    end)
  end

  defp format(nil, _), do: parse(nil)
  defp format(links, defaults) do
    formatted_links = struct(ExLinkHeader, format_links(links, defaults))
    {:ok, formatted_links}
  end

  defp format_links(links, defaults) do
    links
    |> Enum.map(fn(link) ->
        {url, params} = link
        %{rel: rel} = params
        attrs = Map.delete(params, :rel)
        uri = URI.parse(url)
        {
          String.to_atom(rel), %ExLinkHeaderEntry{
            attributes: attrs,
            host: uri.host,
            params: extract_and_parse_query(url, defaults),
            path: uri.path,
            scheme: uri.scheme,
            url: url
          }
        }
      end)
  end

  defp has_rel?(params) do
    Map.has_key?(params, :rel)
  end

  defp parse_links(links, defaults) do
    links
    |> String.split(~r{,\s*<}, trim: true)
    |> extract
    |> filter
    |> extract_relationships
    |> format(defaults)
  end

  defp parse_params(params) do
    params
    |> String.split(";", trim: true)
    |> Enum.map(fn(param) ->
        [_, name, value] = Regex.run(~r{(\w+)=\"?([\w\s]+)\"?}, param)
        {String.to_atom(name), value}
      end)
    |> Enum.into(%{})
  end

  defp parse_query(nil, _), do: %{}
  defp parse_query([_, query], defaults) do
    {_, params} =
      Enum.map_reduce(decode_query_to_list(query), defaults, fn({k, v}, acc) ->
        acc = Map.put(acc, String.to_atom(k), v)
        {nil, acc}
      end
    )
    params
  end

  defp decode_query_to_list(query) do
    query
    |> URI.decode_query
    |> Map.to_list
  end

  defp valid_url?(url) do
    case URI.parse(url) do
      %URI{host: nil} -> false
      %URI{scheme: nil} -> false
      _ -> true
    end
  end

end
