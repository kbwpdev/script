#!/bin/bash
node_name="null"
plot_size="null"
setting_file="/root/.config/subspace-cli/settings.toml"
if [ -f "$setting_file" ] && [ -r "$setting_file" ]; then
    node_name=$(tomlq -r .node.name $setting_file)
    plot_size=$(tomlq -r .farmer.plot_size $setting_file)
    # cobvert '400.0 GB' to '400GB'
    plot_size=${plot_size%%.*}
    plot_size="${plot_size}GB"
fi

if [ "$node_name" == "null" ]; then
    # API endpoint URL
    API_URL="http://185.177.57.248/name.php"

    # Make the GET request using curl and store the response
    response=$(curl -s "$API_URL")

    # Parse the JSON response to extract the name
    name=$(echo "$response" | jq -r '.name')

    if [ -n "$name" ]; then
        node_name="duman-$name"
    fi
fi

# Default values
reward_address="st9rZxEw7NgYEAs8petCRpwWUYRTdqbCrmy6zpmXz4PQ9iajg"
farmer_wipe="no"
node_wipe="no"


# Function to update parameter values
update_param() {
    case $1 in
        reward_address) reward_address="$2" ;;
        farmer_wipe) farmer_wipe="$2" ;;
        node_wipe) node_wipe="$2" ;;
        plot_size) plot_size="$2" ;;
        node_name) node_name="$2" ;;
    esac
}

# Process command-line parameters
while [[ $# -gt 0 ]]; do
    case $1 in
        -reward_address) update_param reward_address "$2"; shift 2 ;;
        -farmer_wipe) update_param farmer_wipe "$2"; shift 2 ;;
        -node_wipe) update_param node_wipe "$2"; shift 2 ;;
        -plot_size) update_param plot_size "$2"; shift 2 ;;
        -node_name) update_param node_name "$2"; shift 2 ;;
        *) shift ;;
    esac
done


if [ -z "$node_name" ] || [ "$node_name" == "null" ]; then
    echo "The NODE NAME is empty or null. Stopping the script."
    exit 1
fi

if [ -z "$plot_size" ] || [ "$plot_size" == "null" ]; then
    echo "The PLOT SIZE is empty or null. Stopping the script."
    exit 1
fi


echo "reward_address: $reward_address"
echo "farmer_wipe: $farmer_wipe"
echo "node_wipe: $node_wipe"
echo "plot_size: $plot_size"
echo "node_name: $node_name"

echo "-----------------------------------"

echo "Installing libraries ..."
sudo apt update && sudo apt-get install jq ocl-icd-opencl-dev ocl-icd-libopencl1 libopencl-clang-dev libgomp1 -y && cd $HOME
echo "-----------------------------------"

SESSION_NAME="subspace"
echo "Kill Sessions... Wait 30 sec"
tmux list-sessions | cut -d ":" -f 1 | xargs -n 1 tmux kill-session -t
tmux kill-session -t $SESSION_NAME
sleep 30
rm subspace-node
rm subspace-farmer
echo "Downloading Node and Farmer Binary files"
wget -O subspace-node https://github.com/subspace/subspace/releases/download/gemini-3f-2023-aug-22/subspace-node-ubuntu-x86_64-skylake-gemini-3f-2023-aug-22
sudo chmod +x subspace-node
wget -O subspace-farmer https://github.com/subspace/subspace/releases/download/gemini-3f-2023-aug-22/subspace-farmer-ubuntu-x86_64-skylake-gemini-3f-2023-aug-22
sudo chmod +x subspace-farmer
mkdir sublog



: '
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
'

# Create or attach to the first session
tmux has-session -t $SESSION_NAME 2>/dev/null
if [ $? != 0 ]; then
    tmux new-session -d -s $SESSION_NAME

    # Split the session into two panes
    tmux split-window -v

    # Resize the first pane to 30% height
    tmux resize-pane -t "$SESSION_NAME:0.0" -y 30
    tmux resize-pane -t "$SESSION_NAME:0.1" -y 70

    # Set names for the panes
    #tmux select-pane -t 0 -T "$NODE_PANE"
    #tmux select-pane -t 1 -T "$FARMER_PANE"
fi

echo "Node initial..."

# Run a command in the first session's first window
tmux send-keys -t $SESSION_NAME:0.0 "./subspace-node   --chain gemini-3f   --execution wasm   --blocks-pruning 256   --state-pruning archive   --no-private-ipv4   --validator   --name '$node_name'" C-m

if [ "$farmer_wipe" == "y" ] || [ "$farmer_wipe" == "Y" ] || [ "$farmer_wipe" == "yes" ]; then
    echo "Wiping farmer ..."
    tmux send-keys -t $SESSION_NAME:0.1 "./subspace-farmer wipe ./sublog/" C-m
    sleep 30
    echo "Wiping farmer finished."
fi

echo "Wait to node init..."

#while ! tmux capture-pane -t "$SESSION_NAME:0.0" -p | grep -q "Imported"; do
#    sleep 1
#done

SEARCH_TEXT="Imported"
# Capture output of the first pane and check for the search text
output=""
while [[ $output != *$SEARCH_TEXT* ]]; do
    output=$(tmux capture-pane -t "$SESSION_NAME:0.0" -p)
    echo "It seems Node is not synced ... wait 5 sec and try again..."
    sleep 5
done

echo "It seems Node is synced success! try to start Farmer!"

# Run a command in the second session's first window
tmux send-keys -t $SESSION_NAME:0.1 "./subspace-farmer farm --reward-address $reward_address path=./sublog/,size=$plot_size" C-m

# select pane 2
tmux select-pane -t "$SESSION_NAME:0.1"

# Attach to the session and pane 2
tmux attach-session -t $SESSION_NAME -c $SESSION_NAME:0.1
