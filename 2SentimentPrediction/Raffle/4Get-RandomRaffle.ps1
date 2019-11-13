$2Eval = "C:\fleitasarts\seattle2019\2SentimentPrediction\Raffle\2Eval.txt"
$Sorted = "C:\fleitasarts\seattle2019\2SentimentPrediction\Raffle\unique-sorted.txt"
$Winners = "C:\fleitasarts\seattle2019\2SentimentPrediction\Raffle\Winners.txt"

[System.IO.File]::WriteAllText(
    $2Eval,
    ([System.IO.File]::ReadAllText($2Eval) -replace " ", "")
)

$Evals = $(foreach ($line in Get-Content $2Eval) {$line.tolower().split(" ")}) | sort | Get-Unique
echo $Evals > $Sorted
Get-Random -Input $Evals -Count 2 > $Winners
