$Evals = $(foreach ($line in Get-Content "C:\fleitasarts\seattle2019\1PowerPlatform\Raffle\2Eval.txt") {$line.tolower().split(" ")}) | sort | Get-Unique
echo $Evals > "C:\fleitasarts\seattle2019\1PowerPlatform\Raffle\unique-sorted.txt"
Get-Random -Input $Evals -Count 2 > "C:\fleitasarts\seattle2019\1PowerPlatform\Raffle\Winners.txt"
