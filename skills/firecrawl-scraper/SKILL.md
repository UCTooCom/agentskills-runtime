---
name: firecrawl-scraper
description: Scrape web content using Firecrawl
author: UCToo
version: 1.0.0
license: MIT
---

inputs:
  url:
    type: string
    description: The URL to scrape
    required: true
  action:
    type: string
    description: Firecrawl action (scrape, search, map, crawl)
    required: false
    default: scrape
  format:
    type: string
    description: Output format (markdown, html, json, etc.)
    required: false
    default: markdown
  apiKey:
    type: string
    description: Firecrawl API key (optional)
    required: false

outputs:
  content:
    type: string
    description: Scraped content

tools:
  - name: FirecrawlTool
    description: Use Firecrawl to scrape web content

steps:
  - name: Scrape Content
    tool: FirecrawlTool
    params:
      action: ${{ inputs.action }}
      query: ${{ inputs.url }}
      apiKey: ${{ inputs.apiKey }}
    result: scrape_result

response:
  content: ${{ steps.Scrape_Content.scrape_result.content }}
