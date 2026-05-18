```mermaid
flowchart LR
    %% Big square on left
    A[Big Square]

    %% Right side: 3 stacked small squares
    subgraph RightSide
        direction TB
        B1[Small 1]
        B2[Small 2]
        B3[Small 3]
    end

    %% Connect to align horizontally
    A --- B1

<div style="display: flex; align-items: stretch; gap: 20px;">

  <!-- Big Square -->
  <div style="
    width: 200px;
    height: 300px;
    border: 2px solid black;
    display: flex;
    align-items: center;
    justify-content: center;">
    Big Square
  </div>

  <!-- Right Side -->
  <div style="
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    height: 300px;">

    <div style="width: 100px; height: 80px; border: 2px solid black;">S1</div>
    <div style="width: 100px; height: 80px; border: 2px solid black;">S2</div>
    <div style="width: 100px; height: 80px; border: 2px solid black;">S3</div>

  </div>

</div>