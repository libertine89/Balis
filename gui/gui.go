package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

type model struct {
	cursor int
	options []string
	selected map[int]struct{}
}

func initialModel() model {
	return model{
		options:  []string{"Option 1", "Option 2", "Option 3", "Option 4"},
		selected: make(map[int]struct{}),
	}
}

// Messages
func (m model) Init() tea.Cmd {
	return nil
}

// Handle key presses
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.options)-1 {
				m.cursor++
			}
		case "enter", " ":
			if _, ok := m.selected[m.cursor]; ok {
				delete(m.selected, m.cursor)
			} else {
				m.selected[m.cursor] = struct{}{}
			}
		}
	}
	return m, nil
}

// Display
func (m model) View() string {
	s := "Select options (press space or enter to toggle, q to quit):\n\n"

	for i, option := range m.options {
		cursor := " " // no cursor
		if m.cursor == i {
			cursor = ">" // cursor
		}

		checked := " " // unchecked
		if _, ok := m.selected[i]; ok {
			checked = "x" // checked
		}

		s += fmt.Sprintf("%s [%s] %s\n", cursor, checked, option)
	}

	s += "\nPress q to exit.\n"
	return s
}

func main() {
	p := tea.NewProgram(initialModel())
	if err := p.Start(); err != nil {
		fmt.Println("Error running program:", err)
		os.Exit(1)
	}
}
