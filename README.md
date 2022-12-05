# Elixir JOP: an in-memory key value logger.  
[![Test](https://github.com/bougueil/jop_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/bougueil/jop_ex/actions/workflows/ci.yml)

Logs in memory spatially and temporarily, key value events.
These events are then flushed to files for analysis.


## Installation


```elixir
def deps do
  [
    {:jop_ex, git: "git://github.com/bougueil/jop_ex"}
  ]
end
```

## Usage
```
  iex> :myjop
  ...> |> JopLog.init()
  ...> |> JopLog.log("key_1", :any_term_112)
  ...> |> JopLog.log("key_2", :any_term_133)
  ...> |> JopLog.flush()
log stored in jop_myjop.2020_05_12_21.42.49_dates.gz
log stored in jop_myjop.2020_05_12_21.42.49_keys.gz
:myjop
```
## Example
```
joplog = JopLog.init(:myjop)
JopLog.log joplog, "key_1", :any_term_112
Process.sleep 12

# clear log
JopLog.clear joplog

JopLog.log joplog, "key_2", :any_term_113
Process.sleep 12

JopLog.log joplog, "key_1", :any_term_112
Process.sleep 12

JopLog.log joplog, "key_2", :any_term_113
JopLog.flush joplog

log stored in jop_myjop.2020_05_12_21.42.49_dates.gz
log stored in jop_myjop.2020_05_12_21.42.49_keys.gz
:myjop
```
will generate both a temporal (by date) and a spatial (by key) log files:

### examining the temporal log file
list all operations by date :

```
zcat jop_myjop.2020_05_12_13.06.38_dates.gz
00:00:00_000.482 "key_2": :any_term_113
00:00:00_014.674 "key_1": :any_term_112
00:00:00_028.568 "key_2": :any_term_113

```

### examining the spatial (by key) log file
list all operations by key :

```
zcat jop_myjop.2020_05_12_13.06.38_keys.gz
"key_1": 00:00:00_014.674 :any_term_112
"key_2": 00:00:00_000.482 :any_term_113
"key_2": 00:00:00_028.568 :any_term_113
```
