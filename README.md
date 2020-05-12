# Elixir JOP: an in-memory key value logger.  

Logs in memory spatially and temporarily, key value events.
These events are then flushed to files for analysis.


## Installation


```elixir
def deps do
  [
    {:jop, git: "git://github.com/bougueil/jop_ex"}
  ]
end
```

## Usage
```
  iex> :myjop
  ...> |> Jop.init()
  ...> |> Jop.log("device_1", data: 112)
  ...> |> Jop.log("device_2", data: 133)
  ...> |> Jop.flush()
log stored in jop_myjop.2020_05_12_21.42.49_dates.gz
log stored in jop_myjop.2020_05_12_21.42.49_keys.gz
[:ok, :ok]
```
## Example
```
log = :myjop |> Jop.init()
Jop.log log, "device_1", data: 112

Process.sleep 12
Jop.clear log
Jop.log log, "device_2", data: 113

Process.sleep 12

Jop.log log, "device_1", data: 112

Process.sleep 12

Jop.log log, "device_2", data: 113
Jop.flush log

log stored in jop_myjop.2020_05_12_21.42.49_dates.gz
log stored in jop_myjop.2020_05_12_21.42.49_keys.gz
[:ok, :ok]
```
will generate both a temporal (by date) and a spatial (by key) log files:

### temporal log file
list all operations by date in file `jop_myjop.2020_05_12_13.06.38_dates.gz`

```
00:00:00_000.482 "device_2": [data: 113]
00:00:00_014.674 "device_1": [data: 112]
00:00:00_028.568 "device_2": [data: 113]

```

### spatial (by key) log file
list all operations by key in file `jop_myjop.2020_05_12_13.06.38_keys.gz`

```
"device_1": [data: 112] 00:00:00_014.674
"device_2": [data: 113] 00:00:00_000.482
"device_2": [data: 113] 00:00:00_028.568
```
