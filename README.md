###  FPGA k-Nearest Neighbors (k-NN) Accelerator

A high-performance RTL implementation of the k-Nearest Neighbors (k=5) classifier built in Verilog and deployed on FPGA.

This project explores how RTL pipeline depth influences DSP inference and timing closure during synthesis, while delivering deterministic sub-microsecond ML inference.

###  Highlights

⚡ Sub-microsecond inference (~0.86 µs)

🧠 Hardware ML classifier for the Iris dataset

🧩 RTL microarchitecture study of pipeline depth

🔧 Demonstrates DSP48 inference vs LUT arithmetic

📉 ~50% LUT reduction using DSP mapping

🕒 Stable timing closure at 181.8 MHz

### Key Insights

Simply adding pipeline stages does NOT guarantee higher performance.

Correct RTL register placement around arithmetic operators is essential for:

✔ Reliable DSP inference
✔ Better timing closure
✔ Improved FPGA resource efficiency

### ⚙️ Hardware Configuration

| Feature         | Value              |
| --------------- | ------------------ |
| Dataset         | Iris (150 samples) |
| Distance Metric | Squared Euclidean  |
| k value         | 5                  |
| Data Format     | Fixed-point        |
| Pipeline Depth  | 3-stage / 5-stage  |
| Platform        | Xilinx Zynq-7000   |


### 🏗 Architecture & Datapath

The classifier is built as a streaming RTL datapath that processes one training sample per clock cycle. Instead of complex control logic, the design relies on pipelined arithmetic to achieve deterministic and high-speed inference.

🔹 Datapath Flow

1️⃣ Test Vector Input

The query vector containing the four Iris features : **sepal_length, sepal_width, petal_length, petal_width** ; is loaded once and held constant during classification.

2️⃣ Training ROM

The 150 Iris training samples are stored in on-chip ROM.

**Each clock cycle: training sample → distance pipeline** ; which enables continuous streaming without memory stalls.

3️⃣ Distance Pipeline

The pipeline computes the squared Euclidean distance between the test vector and each training sample.

distance = **(sl_train − sl_test)² + (sw_train − sw_test)² + (pl_train − pl_test)² + (pw_train − pw_test)²**

Using a D-stage pipeline allows:

✔ one distance result every clock
✔ higher clock frequency
✔ efficient DSP usage

4️⃣ Top-K Sorter

A hardware insertion sorter keeps track of the 5 smallest distances while the pipeline runs which continuously updates the nearest neighbors in real time.

5️⃣ Majority Voting

After all samples are processed, the class labels of the 5 nearest neighbors are evaluated and the most frequent class is selected.

6️⃣ Final Output

The predicted Iris class is produced:

**Setosa | Versicolor | Virginica**

Total classification latency is approximately 0.86 µs on FPGA. 

### **📊 Results & Discussion** :

The FPGA accelerator was evaluated across multiple RTL configurations to understand how pipeline depth and arithmetic mapping affect timing and latency.
All implementations use the same k-NN algorithm (k = 5) and the 150-sample Iris dataset, ensuring a fair architectural comparison.

⚙️ Tested Architectures and latency results 
| Architecture | Pipeline Depth | Arithmetic | Latency |
|--------------|---------------|------------|---------|
| Logic-3stage | 3             | LUT        | 886 ns  |
| Logic-5stage | 5             | LUT        | 912 ns  |
| DSP-3stage   | 3             | DSP48      | **858 ns** ⭐ |
| DSP-5stage   | 5             | DSP48      | 869 ns  |




The DSP-3stage configuration achieves the lowest latency (~0.86 µs) while maintaining stable timing closure at 181.8 MHz.

🧠 Key Observations

✔ DSP mapping improves timing

Mapping arithmetic to DSP48 blocks removes LUT carry-chain critical paths, enabling higher clock frequency and better resource efficiency.

✔ Deeper pipelines alone don’t guarantee better performance

The Logic-5stage design shows that simply adding registers does not fix carry-chain bottlenecks in LUT-based arithmetic.

✔ Balanced microarchitecture wins

The DSP-3stage design provides the best trade-off between pipeline depth and latency, making it the most efficient implementation.

### ⚡ Hardware vs Software Latency

| Platform | Latency |
|---------|--------|
| CPU (NumPy) | ~528 µs |
| GPU (CuPy) | ~33 µs |
| FPGA | **~0.86 µs** |

This demonstrates orders-of-magnitude lower latency for single-sample inference using FPGA hardware acceleration.

🏁 Takeaway

Efficient FPGA acceleration depends not only on pipelining but on aligning RTL structure with DSP hardware primitives, enabling predictable timing and low-latency inference.
