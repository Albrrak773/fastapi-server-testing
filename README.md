A Tool I built to mesaure the difference between running a FastAPI server either **synchronously** (Threadpools) or with **async/await**.

### How it works
The script spins up a new server, stress tests it then gathers RAM and Thread Usage over the life time of the test
and finally shuts it down and prints the results in a beautiful way.

I use [hey](https://github.com/rakyll/hey) for stress testing the server by making a lot of request with a lot of concurency.
And I capture the [PID](https://en.wikipedia.org/wiki/Process_identifier) of the created server.
I sample The RAM usage from the `/proc/<pid>/status` file 
I get the Max RAM and the thread count from the same place.

Cool terminal output with achieved with colors, emojis and Loading spinners thanks to [bash_loading_animations](https://github.com/Silejonu/bash_loading_animations)
### Running Benchmark
![status](https://github.com/user-attachments/assets/0c5d5bbd-95d9-4451-aae7-39dcba803daa)

### Results
<img width="1060" height="937" alt="screenshot-2025-12-15_21-30-07" src="https://github.com/user-attachments/assets/6b44f0af-764d-4ab6-b22b-958e48b881f6" />
