# How to make ChatGPT generate Code

This is a study and proof of concept to facilitate ChatGPT to write code using __AI Automated Test Drive Development__.

The idea is to give ChatGPT three inputs into the API:

1. A reference test module
2. An implementation module
3. The result of running the test against the implementation result

And then ask ChatGPT to produce an updated implementation, and keep doing this in a loop.

## API Key

In order to run this you have to have an openapi API KEY, and put it into the environment as `OPENAI_API_KEY`

For example:

```bash
export OPENAI_API_KEY=xxxxxxx
```

## Fix the code to pass the test

The `gpt.exs test <module> <iteration>` command will run the test and ask ChatGPT
for code improvements. It will keep doing this up to <iterations> in a loop.

```bash
export OPENAI_API_KEY=xxxxxxx
./gpt.exs test day1 4
```

## Update the code according to my instruction

The `gpt.exs update <module> <instructions ...>` command will ask ChatGPT to make
changes to the code according to the provided instruction

```bash
export OPENAI_API_KEY=xxxxxxx
./gpt.exs update day1 remove the moduledoc
```
