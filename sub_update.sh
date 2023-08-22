#!/bin/bash
SESSION_NAME="subspace"
echo "Kill Sessions"
tmux list-sessions | cut -d ":" -f 1 | xargs -n 1 tmux kill-session -t
tmux kill-session -t $SESSION_NAME
sleep 30
rm subspace-node
rm subspace-farmer
echo "Downloading Node and Farmer Binary files"
wget -O subspace-node https://github.com/subspace/subspace/releases/download/gemini-3f-2023-aug-21/subspace-node-ubuntu-x86_64-skylake-gemini-3f-2023-aug-21
sudo chmod +x subspace-node
wget -O subspace-farmer https://github.com/subspace/subspace/releases/download/gemini-3f-2023-aug-21/subspace-farmer-ubuntu-x86_64-skylake-gemini-3f-2023-aug-21
sudo chmod +x subspace-farmer
mkdir sublog


read -p "Reward Address (default: st9rZxEw7NgYEAs8petCRpwWUYRTdqbCrmy6zpmXz4PQ9iajg): " reward_address
reward_address=${reward_address:-"st9rZxEw7NgYEAs8petCRpwWUYRTdqbCrmy6zpmXz4PQ9iajg"}

read -p "Enter Node Name (default: duman): " node_name
node_name=${node_name:-"duman"}
new_node_name="duman-$node_name"
node_name="$new_node_name"

read -p "Enter Plot Size (default: 320GB): " plot_size
plot_size=${plot_size:-"320GB"}

read -p "Farmer wipe? (y/n) (default: n): " farmer_wipe
farmer_wipe=${farmer_wipe:-"n"}

read -p "Node wipe? (y/n) (default: n): " node_wipe
node_wipe=${node_wipe:-"n"}

# Create or attach to the first session
tmux has-session -t $SESSION_NAME 2>/dev/null
if [ $? != 0 ]; then
    tmux new-session -d -s $SESSION_NAME
    # Split the window into two panes
    tmux split-window -v -p 30 -t $SESSION_NAME
    tmux select-pane -t 0    
fi

echo "Node initial..."

# Run a command in the first session's first window
tmux send-keys -t $SESSION_NAME:0.0 "./subspace-node   --chain gemini-3f   --execution wasm   --blocks-pruning 256   --state-pruning archive   --no-private-ipv4   --validator   --name '$node_name'" C-m

echo "Wait 5 Minute to node init..."
sleep 300
echo "Farmer initial..."
sleep 2

if [ "$farmer_wipe" == "y" ] || [ "$farmer_wipe" == "Y" ]; then
    tmux send-keys -t $SESSION_NAME:0.1 "./subspace-farmer wipe ./sublog/" C-m
    sleep 60
fi

# Run a command in the second session's first window
tmux send-keys -t $SESSION_NAME:0.1 "./subspace-farmer farm --reward-address $reward_address path=./sublog/,size=$plot_size" C-m

# Attach to the session and pane 2
tmux attach-session -t $SESSION_NAME -c $SESSION_NAME:0.1
