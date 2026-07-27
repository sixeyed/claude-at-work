# Conversation: What's Coming in the Next Version of .NET

*Date: Monday, April 27, 2026*

---

**User** — *2026-04-27, 14:32*

what's coming up in the next version of .net?

---

**Claude** — *2026-04-27, 14:32*

The next version is **.NET 11**, which is currently in preview (Preview 1 dropped in February 2026) with general availability targeted for **November 2026**. Unlike .NET 10, it's an STS (Standard Term Support) release, so it'll only get two years of support.

Here's what's shaping up so far:

**Runtime and platform**

- Continued reduction in Mono runtime usage — CoreCLR becomes a target in the .NET WebAssembly SDK (used by some Blazor flavors), and CoreCLR becomes the default for Android builds (it was experimental in .NET 10). This is another step toward removing Mono dependencies entirely.
- Zstandard compression support has been added to the libraries, with improved performance.
- Runtime modifications aimed at improving the debugging experience for asynchronous code.

**C# 15**

- Collection expression arguments — these let you customize a collection object when it's created. To preserve backward compatibility, modifying arguments (like setting capacity or a custom comparer) are passed as a dummy element, e.g. `List<string> names = [with(capacity: values.Count * 2), .. values];`

**ASP.NET Core direction**

- The ASP.NET Core roadmap for .NET 11 is prioritizing "building agentic web apps" and "Copilot-assisted web development," including support for the Model Context Protocol (MCP) so .NET applications can act as tools for AI agents. This AI-heavy direction has gotten a mixed reception — some devs would rather see attention on things like Native AOT and reflection in Blazor WebAssembly.

If you're deciding whether to adopt it, the LTS/STS distinction matters: .NET 10 (the current LTS) will be the long-term baseline through to roughly late 2028, whereas .NET 11 is more of a stepping stone toward .NET 12.

---

**User** — *2026-04-27, 14:35*

can you capture this conversation in an artifact - with timestamps for the prompt and response

---

**Claude** — *2026-04-27, 14:35*

*[This document.]*
