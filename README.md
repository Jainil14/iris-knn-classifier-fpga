# iris-knn-classifier-fpga
Hardware-Accelerated KNN Classifier on FPGA :

An ultra-fast, 4-stage pipelined hardware implementation of the K-Nearest Neighbors (KNN) algorithm, architected to perform machine learning classifications at nanosecond speeds after achieving timing closure at 178.6 MHz.

This project demonstrates the immense performance gains of hardware acceleration by implementing a KNN (k=5) classifier in Verilog for an Altera Cyclone II FPGA. It processes a custom fixed-point version of the Iris dataset and delivers classification results orders of magnitude faster than a traditional CPU-based software approach.

👉 Key Features & Highlights

🚀 Nanosecond-Level Performance:    Achieves a full classification in just 884 nanoseconds, a speedup of over 1700x compared to software, by running on a stable 178.6 MHz clock.

⚙️ 4-Stage Compute Pipeline:    A deep, synchronous pipeline streams the dataset through the compute engine, processing one data point every single clock cycle without stalls.

⏱️ Verified Timing Closure:   Post-synthesis static timing analysis (STA) confirms the design is robust. The worst-path delay was measured at 5.4 ns, comfortably meeting the 5.6 ns (178.6 MHz) clock target with positive timing slack.

🧠 Custom Fixed-Point Data Representation:   The original floating-point Iris dataset was pre-processed by multiplying by 10, converting to a 16-bit integer format, and then representing it in hex for on-chip storage. This allows for purely integer-based hardware, dramatically simplifying the logic.

💡 Synthesis-Aware Design:   The Verilog is written to allow the synthesis tool to infer the use of dedicated DSP blocks for multiplication, resulting in a highly efficient and performant hardware implementation.


👉 Hardware vs. Software Performance Metrics 📈

| Metric              | Hardware (This Project)               | Software (Python, Single Core)      |
| :------------------ | :------------------------------------ | :---------------------------------- |
| **Clock Frequency** | **178.6 MHz** (5.6 ns period)         | ~3.4 GHz (Typical modern CPU)       |
| **Execution Model** | **Fully Pipelined** (1 point/cycle)   | **Sequential Loops** & OS Overhead  |
| **Latency / Vector**| **884 nanoseconds** | **~1500 - 1600 microseconds** (1.5 - 1.6 ms) |
| **Performance Gain**| **~1,700x - 1,800x Speedup** | Baseline                            |

👉 Architecture Deep Dive:

The system is architected as a single, all-in-one processor that continuously streams data through three sequential hardware blocks. This design ensures the entire KNN algorithm executes in a predictable and fixed number of clock cycles.

1. Data Pre-processing & On-Chip ROM :

   To prepare the data for hardware, the original floating-point Iris dataset was converted to a 16-bit fixed-point format. This was achieved by multiplying each      feature by 10 and rounding to the nearest integer. The entire 150-entry dataset was then stored on-chip in a synthesized LUT-based ROM using a 66-bit               {petal_width, petal_length, sepal_width, sepal_length, class_label} structure.

   This design provides single-cycle read access to each data point, which is critical for feeding the compute pipeline without any stalls.      It also explains the 0% BRAM usage, as the dataset lives directly in the FPGA's logic fabric.

2. The 4-Stage Compute Pipeline (The Core Engine) :
   
   This is where the mathematical heavy lifting happens. The pipeline accepts one training data point from the ROM each clock cycle and calculates its squared         Euclidean distance from the input test_vector.

   Stage 1 (Parallel Difference):
   Fetches a 66-bit data point from ROM and calculates the signed difference (training_feature - test_feature) for all four features simultaneously.

   Stage 2 (Parallel Squaring):
   Calculates (difference)² for all four features. This is where the synthesis tool infers the use of the FPGA's dedicated DSP blocks (hardware multipliers).

   Stage 3 (Adder Tree Summation):
   Sums the four squared differences to produce the final squared Euclidean distance.

   Stage 4 (Output Buffering):
    Registers the final distance to cleanly hand off the value to the sorter module.

3. High-Speed Insertion Sorter :
   
    As the pipeline outputs a new distance value every clock cycle, the sorter's job is to maintain a real-time, sorted list of the top 5 smallest distances found      so far.

   Implementation: A fully-unrolled, 5-register insertion sorter. It processes one new distance value every single clock cycle, ensuring no stalls or back-pressure    on the compute pipeline.

4. Instantaneous Majority Voting :
   
    Once all 150 data points have been processed, a simple, combinatorial voting block resolves the final class in a single clock cycle, adding negligible latency.

