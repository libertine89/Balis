package main

import (
	"fmt"
	tea "github.com/charmbracelet/bubbletea"
)

type model struct{}

func (m model) Init() tea.Cmd { return nil }
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg.(type) {
	case tea.KeyMsg:
		return m, tea.Quit
	}
	return m, nil
}
func (m model) View() string { return "Bubble Tea works!\nPress any key to exit." }

func main() {
	if err := tea.NewProgram(model{}).Start(); err != nil {
		fmt.Println("Error:", err)
	}
}
