# Elixir JOP: an in-memory key value logger.  

Logs in memory spatially and temporarily, key value events.
These events are then flushed to files for analysis.


## Installation


```elixir
def deps do
  [
  {:jop_ex, git: "https://github.com/bougueil/jop_ex.git"}
  ]
end
```

## Usage
```
  iex> :mylog
  ...> |> Jop.init()
  ...> |> Jop.log("mykey1", {:vv,112})
  ...> |> Jop.log("mykey2", {:vv,113})
  ...> |> Jop.flush()
  ...> |> length() > 0
  true
```
## Example
```
log = :myjop
Jop.init(log)
|> Jop.log(log, "mykey1", {:vv, 112})

:timer.sleep(12)
Jop.clear(log)
|> Jop.log(log, "mykey2", {:vv, 113})

:timer.sleep(12)

Jop.log(log, "mykey1", {:vv, 112})

:timer.sleep(12)

Jop.log(log, "mykey2", {:vv, 113})
|> Jop.flush()
```
will generate both a temporal and a spatial log files:

### temporal log file
```
jop_myjop.2018_01_20_17.10.21_dates :
00:00:00_000.000 <<109,121,107,101,121,50>>: {vv,113}
00:00:00_013.013 <<109,121,107,101,121,49>>: {vv,112}
00:00:00_026.026 <<109,121,107,101,121,50>>: {vv,113}
```
### spatial log file
```
jop_myjop.2018_01_20_17.10.21_keys :
<<109,121,107,101,121,49>>: {vv,112} 00:00:00_013.013
<<109,121,107,101,121,50>>: {vv,113} 00:00:00_000.000
<<109,121,107,101,121,50>>: {vv,113} 00:00:00_026.026
```
