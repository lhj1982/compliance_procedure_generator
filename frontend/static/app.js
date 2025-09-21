// Questions hardcoded based on example_questions.txt
const COMPLIANCE_QUESTIONS = [
    {
        id: 'control_name',
        question: 'Control Name',
        type: 'text',
        placeholder: 'e.g., Monthly CDE Privileged Access Review'
    },
    {
        id: 'control_owner',
        question: 'Control Owner / Performer',
        type: 'textarea',
        placeholder: 'Role/Team and Backup/Delegate information'
    },
    {
        id: 'frequency',
        question: 'Frequency',
        type: 'textarea',
        placeholder: 'Cadence and execution window details'
    },
    {
        id: 'purpose',
        question: 'Purpose / PCI Risk Mitigation',
        type: 'textarea',
        placeholder: 'Explain the PCI-related risk this control addresses and how it reduces risk'
    },
    {
        id: 'procedure_steps',
        question: 'Procedure Steps',
        type: 'textarea',
        placeholder: 'Detailed step-by-step instructions that a new engineer could follow'
    },
    {
        id: 'tools_systems',
        question: 'Tools & Systems',
        type: 'textarea',
        placeholder: 'List the platforms, dashboards, or applications used'
    },
    {
        id: 'access_requirements',
        question: 'Access Requirements',
        type: 'textarea',
        placeholder: 'Define repos, folders, credentials, or elevated privileges needed'
    },
    {
        id: 'starting_point',
        question: 'Starting Point',
        type: 'textarea',
        placeholder: 'State exactly where the work begins (e.g., dashboard link, console path)'
    },
    {
        id: 'checks_criteria',
        question: 'Checks & Criteria',
        type: 'textarea',
        placeholder: 'What standards, thresholds, or PCI requirements are verified'
    },
    {
        id: 'failure_handling',
        question: 'Failure Handling',
        type: 'textarea',
        placeholder: 'Escalation path and remediation actions if the control check fails'
    },
    {
        id: 'additional_involvement',
        question: 'Additional Involvement',
        type: 'textarea',
        placeholder: 'Note if other teams or individuals are involved pre-approval'
    },
    {
        id: 'approval_signoff',
        question: 'Approval / Sign-off',
        type: 'textarea',
        placeholder: 'Define who signs off or provides final validation'
    },
    {
        id: 'evidence_storage',
        question: 'Evidence Storage',
        type: 'textarea',
        placeholder: 'Where control evidence is stored (e.g., SharePoint, Jira, secure folder)'
    },
    {
        id: 'work_location',
        question: 'Work Location',
        type: 'textarea',
        placeholder: 'Specify if performed by a local team, offshore team, or multiple sites'
    },
    {
        id: 'dependencies',
        question: 'Dependencies',
        type: 'textarea',
        placeholder: 'Identify upstream/downstream dependencies'
    }
];

class ComplianceApp {
    constructor() {
        this.selectedTeam = null;
        this.teams = [];
        // Configure API base URL - works for both localhost and Docker
        this.apiBaseUrl = this.getApiBaseUrl();
        console.log('Constructor - API Base URL set to:', this.apiBaseUrl);
        this.init();
    }

    getApiBaseUrl() {
        // For localhost development
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log('Detected localhost, using API URL: http://localhost:9090');
            return 'http://localhost:9090';
        }
        // For Docker or production - assume backend is on same host, different port
        const apiUrl = `${window.location.protocol}//${window.location.hostname}:9090`;
        console.log('Detected non-localhost, using API URL:', apiUrl);
        return apiUrl;
    }

    async init() {
        await this.loadTeams();
        this.setupEventListeners();
    }

    async loadTeams() {
        try {
            const teamsUrl = `${this.apiBaseUrl}/api/teams`;
            console.log('Loading teams from URL:', teamsUrl);
            const response = await fetch(teamsUrl);
            if (response.ok) {
                this.teams = await response.json();
                this.populateTeamDropdown();
            } else {
                console.error('Failed to load teams');
                // Fallback to sample teams if API fails
                this.teams = [
                    { id: 1, name: 'Engineering' },
                    { id: 2, name: 'Legal' },
                    { id: 3, name: 'HR' },
                    { id: 4, name: 'Finance' },
                    { id: 5, name: 'Operations' }
                ];
                this.populateTeamDropdown();
            }
        } catch (error) {
            console.error('Error loading teams:', error);
            // Fallback to sample teams
            this.teams = [
                { id: 1, name: 'Engineering' },
                { id: 2, name: 'Legal' },
                { id: 3, name: 'HR' },
                { id: 4, name: 'Finance' },
                { id: 5, name: 'Operations' }
            ];
            this.populateTeamDropdown();
        }
    }

    populateTeamDropdown() {
        const dropdown = document.getElementById('team-dropdown');
        dropdown.innerHTML = '<option value="">Select a team...</option>';

        this.teams.forEach(team => {
            const option = document.createElement('option');
            option.value = team.id;
            option.textContent = team.name;
            dropdown.appendChild(option);
        });
    }

    setupEventListeners() {
        // Team selection change
        document.getElementById('team-dropdown').addEventListener('change', (e) => {
            this.handleTeamSelection(e.target.value);
        });

        // Form submission
        document.getElementById('compliance-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleFormSubmission();
        });

        // Reset button
        document.getElementById('reset-btn').addEventListener('click', () => {
            this.resetForm();
        });

        // Modal close events
        document.querySelectorAll('.close').forEach(closeBtn => {
            closeBtn.addEventListener('click', (e) => {
                this.closeModal(e.target.closest('.modal'));
            });
        });

        // Click outside modal to close
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal(e.target);
            }
        });
    }

    handleTeamSelection(teamId) {
        if (!teamId) {
            this.showWelcomeView();
            return;
        }

        this.selectedTeam = this.teams.find(team => team.id == teamId);
        if (this.selectedTeam) {
            this.showQuestionsView();
            this.generateQuestions();
        }
    }

    showWelcomeView() {
        document.getElementById('welcome-view').classList.add('active');
        document.getElementById('questions-view').classList.remove('active');
    }

    showQuestionsView() {
        document.getElementById('welcome-view').classList.remove('active');
        document.getElementById('questions-view').classList.add('active');

        // Update header
        document.getElementById('selected-team-title').textContent = `Compliance Questions - ${this.selectedTeam.name}`;
        document.getElementById('selected-team-name').textContent = `Team: ${this.selectedTeam.name}`;
    }

    generateQuestions() {
        const container = document.getElementById('questions-container');
        container.innerHTML = '';

        COMPLIANCE_QUESTIONS.forEach((question, index) => {
            const questionDiv = document.createElement('div');
            questionDiv.className = 'question-item';

            const questionTitle = document.createElement('h4');
            questionTitle.textContent = `${index + 1}. ${question.question}`;
            questionDiv.appendChild(questionTitle);

            const formGroup = document.createElement('div');
            formGroup.className = 'form-group';

            let input;
            if (question.type === 'textarea') {
                input = document.createElement('textarea');
                input.rows = 4;
            } else {
                input = document.createElement('input');
                input.type = question.type;
            }

            input.id = question.id;
            input.name = question.id;
            input.placeholder = question.placeholder;
            input.required = true;

            formGroup.appendChild(input);
            questionDiv.appendChild(formGroup);
            container.appendChild(questionDiv);
        });
    }

    async handleFormSubmission() {
        if (!this.selectedTeam) {
            alert('Please select a team first.');
            return;
        }

        // Collect form data
        const formData = {
            team_id: this.selectedTeam.id,
            team_name: this.selectedTeam.name,
            answers: {}
        };

        COMPLIANCE_QUESTIONS.forEach(question => {
            const input = document.getElementById(question.id);
            if (input && input.value.trim()) {
                formData.answers[question.id] = {
                    question: question.question,
                    answer: input.value.trim()
                };
            }
        });

        // Validate that at least some questions are answered
        if (Object.keys(formData.answers).length === 0) {
            alert('Please answer at least one question before submitting.');
            return;
        }

        // Disable submit button and show loading
        const submitBtn = document.getElementById('submit-btn');
        const originalText = submitBtn.textContent;
        submitBtn.disabled = true;
        submitBtn.textContent = 'Generating Document...';

        try {
            const submitUrl = `${this.apiBaseUrl}/api/submit_answers`;
            console.log('Submitting to URL:', submitUrl);
            console.log('Form data:', formData);

            const response = await fetch(submitUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(formData)
            });

            if (response.ok) {
                const result = await response.json();
                this.showSuccessModal(result);
            } else {
                const error = await response.json();
                alert(`Error: ${error.message || 'Failed to generate document'}`);
            }
        } catch (error) {
            console.error('Error submitting form:', error);
            alert('Error: Failed to connect to server');
        } finally {
            // Re-enable submit button
            submitBtn.disabled = false;
            submitBtn.textContent = originalText;
        }
    }

    showSuccessModal(result) {
        const modal = document.getElementById('success-modal');
        const documentName = document.getElementById('document-name');
        const downloadLink = document.getElementById('download-link');

        documentName.textContent = result.document_name;
        downloadLink.href = result.download_url;
        downloadLink.download = result.document_name;

        modal.classList.remove('hidden');
    }

    closeModal(modal) {
        if (modal) {
            modal.classList.add('hidden');
        }
    }

    resetForm() {
        if (confirm('Are you sure you want to reset the form? All entered data will be lost.')) {
            COMPLIANCE_QUESTIONS.forEach(question => {
                const input = document.getElementById(question.id);
                if (input) {
                    input.value = '';
                }
            });
        }
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new ComplianceApp();
});