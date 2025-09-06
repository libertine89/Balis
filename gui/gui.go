package main

import (
	"fmt"
	"os"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#FF7F50"))
	cursorStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#00FFFF"))
	selectedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#00FF00")).Bold(true)
	boxStyle      = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("#FFA500")).
			Padding(1, 2)
)

type model struct {
	cursor        int
	prevCursor    int
	options       []string
	selected      map[int]struct{}
	animating     bool
	animDirection int
}

func initialModel() model {
	return model{
		options:  []string{"Play Game", "Settings", "About", "Quit"},
		selected: make(map[int]struct{}),
	}
}

// Message for animation ticks
type tickMsg struct{}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.prevCursor = m.cursor
				m.cursor--
				m.animDirection = -1
				m.animating = true
				return m, tick()
			}
		case "down", "j":
			if m.cursor < len(m.options)-1 {
				m.prevCursor = m.cursor
				m.cursor++
				m.animDirection = 1
				m.animating = true
				return m, tick()
			}
		case "enter", " ":
			if _, ok := m.selected[m.cursor]; ok {
				delete(m.selected, m.cursor)
			} else {
				m.selected[m.cursor] = struct{}{}
			}
		}
	case tickMsg:
		m.animating = false
	}
	return m, nil
}

// Animation tick: small delay for cursor slide
func tick() tea.Cmd {
	return tea.Tick(time.Millisecond*50, func(time.Time) tea.Msg {
		return tickMsg{}
	})
}

func (m model) View() string {
	s := titleStyle.Render("🌟 Bubble Tea Animated Menu 🌟") + "\n\n"

	for i, option := range m.options {
		cursor := "  "
		optStyle := lipgloss.NewStyle()

		// Highlight cursor position
		if i == m.cursor {
			cursor = "→ "
			optStyle = cursorStyle
		}
		if _, ok := m.selected[i]; ok {
			optStyle = selectedStyle
		}

		// Animate cursor moving: show a "shadow" at previous position
		line := fmt.Sprintf("%s%s", cursor, optStyle.Render(option))
		if m.animating && i == m.prevCursor {
			line = fmt.Sprintf("  %s", optStyle.Render(option))
		}

		s += boxStyle.Render(line) + "\n"
	}

	return lipgloss.PlaceHorizontal(50, lipgloss.Center, s)
}

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if err := p.Start(); err != nil {
		fmt.Println("Error running program:", err)
		os.Exit(1)
	}
}
