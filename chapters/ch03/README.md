# Chapter 3 — Using Claude Desktop and Cowork

This is the chapter where the work moves onto your machine. Most of the exercises produce files in your own folders rather than artifacts you download, so there's less to publish here than in chapters 1 and 2 — what's below is the output worth comparing against.

## The Our World In Data research

Section 3.3 — *Working with local files and folders*.

[`Connectivity-Research-Orbit-Report.docx`](Connectivity-Research-Orbit-Report.docx) is the report Claude wrote after four turns exploring three OWID datasets in a local folder: internet adoption, R&D researchers per million people, and objects launched into space.

To reproduce it, download the three datasets from the links in section 3.3, drop the ZIPs into a folder called `owid`, and point a Cowork task at it. Claude extracts them, inspects the CSV headers, then writes and runs pandas and SciPy code in the sandbox.

The thing worth noticing isn't the report — it's where the work happened. The CSVs were never read into the context. Claude wrote analysis code, ran it locally, and reasoned over the results, which is why the approach scales to datasets far larger than any context window. The Python scripts themselves aren't saved; they're intermediate tool output. Ask Claude to keep them if you want to take over the analysis yourself.

One caveat the chapter calls out and the report demonstrates: Claude needed population data to normalise, assumed it couldn't fetch a large CSV, and generated a summary from its own training data instead. That part is the least trustworthy thing in the document. Fetch your own reference data when it matters.

## The lab — design documents in Git

Section 3.7 — *Your turn: set up your application project*.

[`lab`](lab) holds my design documents after the Cowork session. **This is the output, not the input.** The lab starts from the chapter 2 designs — [`chapters/ch02/lab/docs`](../ch02/lab/docs), which specify .NET — and the prompt switches the stack:

> I have decided to use Python instead of .NET - update all the documents with this change and review for correctness.

So the set here is the rewritten one: FastAPI and Python throughout, same eight documents, same structure. Diffing the two folders is a good way to see how thoroughly Claude carried a single decision through a document set — and to spot anything it missed.

That rewrite took about 10 minutes across two commits. The point of the exercise isn't the speed, it's that the folder was a Git repo, so reviewing a change that size meant reading a diff rather than re-reading eight documents.

### The golden source

The CollabHub project has its own repo: **https://github.com/sixeyed/claude-at-work-project**.

That's the canonical version and the one to follow if you're building along. It carries the real commit history — including the .NET → Python rewrite as an actual diff you can read — and it keeps moving through Phase 2 and Phase 3 as the system gets built, deployed, and handed over to agents.

What's in [`lab/docs`](lab/docs) here is a snapshot: the design set exactly as it stood at the end of this chapter, so the book and the repo agree. Use the snapshot to check your own output against mine at this point in the story; use the project repo to see where it all ends up.

## Not in the repo

Some of this chapter's output is specific to your machine or your accounts, so there's nothing useful to publish:

- The `summary.md` from the Downloads folder exercise in section 3.2.
- The weekly email summary and the drafted reply from section 3.5 — both are personal mailbox content.
- The live email-traffic dashboard from section 3.6. Listing 3.2 in the book shows the classification function if you want to see the shape of the generated code.
