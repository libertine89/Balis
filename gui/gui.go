package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#FFFFFF")) // white text for contrast

	cursorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFF00")) // yellow cursor

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#00FF00")).
			Bold(true)

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("#FFFFFF")).
			Padding(1, 2)

	background = lipgloss.NewStyle().
			Background(lipgloss.Color("#00BFFF")) // bright blue
)

type model struct {
	cursor   int
	options  []string
	selected map[int]struct{}
	width    int
	height   int
}

func initialModel() model {
	return model{
		options:  []string{"Play Game", "Settings", "About", "Quit"},
		selected: make(map[int]struct{}),
	}
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
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

func (m model) View() string {
	s := titleStyle.Render("🌟 Bubble Tea Fullscreen Menu 🌟") + "\n\n"

	for i, option := range m.options {
		cursor := "  "
		optStyle := lipgloss.NewStyle()
		if m.cursor == i {
			cursor = "→ "
			optStyle = cursorStyle
		}
		if _, ok := m.selected[i]; ok {
			optStyle = selectedStyle
		}
		s += boxStyle.Render(fmt.Sprintf("%s%s", cursor, optStyle.Render(option))) + "\n"
	}

	// Fill the terminal and center vertically + horizontally
	return background.Render(
		lipgloss.Place(
			m.width, m.height,
			lipgloss.Center, lipgloss.Center,
			s,
		),
	)
}

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if err := p.Start(); err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}
}
