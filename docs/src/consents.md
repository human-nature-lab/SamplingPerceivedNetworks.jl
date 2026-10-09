# Consents

Pass a `Dict` from node name to consent code as the second argument:

| code | meaning |
|---|---|
| 0 | no consent |
| 1 | survey only |
| 2 | survey and photo |
| 3 | photo only |

```julia
lists = samplenetwork(rng, graph, consents; deployed_design...)
```

Only perceivers with code 1 or 2 receive a list; the rest are absent from the
result. A pair is shown only if both members have code 2 or 3. In the Honduras
survey, respondents saw the faces of the people in each pair rather than their
names, so a pair requires both photos. A perceiver can therefore receive a short or empty
list.

Every node needs an entry in `consents`, and no value may be `missing`.
Otherwise `samplenetwork` throws an `ArgumentError`.
