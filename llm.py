from flask import Flask, request, jsonify
import google.generativeai as genai
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS if needed for cross-origin requests

# Set your Google API key here
GOOGLE_API_KEY = 'AIzaSyAAAA0G38_VkZkYlBRam1M-F8Pmk88hY44'
genai.configure(api_key=GOOGLE_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

@app.route('/generate', methods=['GET'])
def generate_content():
    level = request.args.get('level')  # Get the level from the query string

    if not level:
        return jsonify({'error': 'Level is required'}), 400

    # Construct prompt based on selected difficulty
    if level == 'beginner':
        prompt = ("Generate 20 beginner-level Java multiple choice questions (MCQs) about variables, loops, and basic syntax. "
                  "For each question, provide 4 options. Start the question with 'qstn:', options with 'opt:' with each option separated by comma, and the correct answer with 'ans:' and topic with 'top:'. "
                  "Do not provide any other message or use any special characters or formatting unless necessary in questions. Separate each question set with a newline. Put a question and its options and answer in a single line with only space separating.")
    elif level == 'intermediate':
        prompt = ("Generate 20 intermediate-level Java multiple choice questions (MCQs) about functions, classes, and data structures. "
                  "For each question, provide 4 options. Start the question with 'qstn:', options with 'opt:' with each option separated by comma, and the correct answer with 'ans:'and topic with 'top:'. "
                  "Do not provide any other message or use any special characters or formatting unless necessary in questions. Separate each question set with a newline. Put a question and its options and answer in a single line with only space separating.")
    elif level == 'advanced':
        prompt = ("Generate 20 advanced-level Java multiple choice questions (MCQs) about algorithms, data science, and optimization. "
                  "For each question, provide 4 options. Start the question with 'qstn:', options with 'opt:' with each option separated by comma, and the correct answer with 'ans:'and topic with 'top:'. "
                  "Do not provide any other message or use any special characters or formatting unless necessary in questions. Separate each question set with a newline. Put a question and its options and answer in a single line with only space separating.")
    else:
        return jsonify({'error': 'Invalid level'}), 400

    try:
        # Generate content using the Google Generative AI model
        response = model.generate_content(prompt)
        generated_content = response.text

        # Split the generated content by newline to separate each question
        questions_and_options = generated_content.split('\n')
        mcqs = []

        # Process each question
        for q in questions_and_options:
            try:
                if 'qstn:' in q and 'opt:' in q and 'ans:' in q and 'top:' in q:
                    question_part = q.split('qstn:', 1)[1].split('opt:', 1)[0].strip()
                    options_part = q.split('opt:', 1)[1].split('ans:', 1)[0].strip()
                    answer_part = q.split('ans:', 1)[1].split('top:', 1)[0].strip()
                    topic_part = q.split('top:', 1)[1].strip()

                    options = options_part.split(',')

                    mcqs.append({
                        'question': question_part,
                        'options': options,
                        'correct_answer': answer_part,
                        'topic' : topic_part
                    })
            except Exception as e:
                print(f"Error processing question: {e}")

        if not mcqs:
            return jsonify({'error': 'No valid questions generated'}), 500

        return jsonify({'mcqs': mcqs})

    except Exception as e:
        return jsonify({'error': f'Failed to generate content: {str(e)}'}), 500

@app.route('/subtopics', methods=['GET'])
def generate_subtopics():
    topic = request.args.get('topic')
    priority = request.args.get('priority')

    if not topic:
        return jsonify({'error': 'Topic is required'}), 400
    if not priority:
        return jsonify({'error': 'Priority is required'}), 400

    try:
        # Construct prompt to generate subtopics
        prompt = (f"Generate subtopics for the topic '{topic}' in context of Java."
                  f"The priority is {priority} out of 1. More priority means less knowledge and has to be taught from bare basics as if user is total beginner."
                  "Less priority means user is knowledgable enough and can be taught accordingly. Provide 3 to 6 subtopics that are essential to understanding this topic based on its priority. " 
                  "List the subtopics as a plain text, each separated by a newline.At the end, include a title for a quiz to assess the user's understanding of the topic. ")

        # Generate content using the Google Generative AI model
        response = model.generate_content(prompt)
        generated_subtopics = response.text.split('\n')

        # Filter out any empty subtopics
        subtopics = [subtopic.strip() for subtopic in generated_subtopics if subtopic.strip()]

        if not subtopics:
            return jsonify({'error': 'No subtopics generated'}), 500

        return jsonify({'subtopics': subtopics})

    except Exception as e:
        return jsonify({'error': f'Failed to generate subtopics: {str(e)}'}), 500
    


@app.route('/content', methods=['GET'])
def get_content():
    subtopic = request.args.get('subtopic')
    
    if not subtopic:
        return jsonify({'error': 'Subtopic parameter is required'}), 400
    
    try:
        # Replace this with your actual logic to fetch content
        prompt = (f"Generate some content for learning this topic '{subtopic}' in the context of Java. Use a fun and interesting tone to keep the user engaged."
                  "Do not use too big english words. keep the language conversational. The code snippets should be enclosed within ``, $ for bullet points, bold enclosed between *."
                 "Do not use these characters for anything else or any other special characters unless needed in the text itself.")
        # Generate content using the model
        response = model.generate_content(prompt)

        # Return the generated content as plain text
        return jsonify({'content': response.text})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/questions', methods=['GET'])
def get_quizcontent():
    subtopic = request.args.get('topic')
    
    if not subtopic:
        return jsonify({'error': 'Subtopic parameter is required'}), 400
    
    try:
        # Replace this with your actual logic to fetch content
        prompt = (f"Generate 10 Java multiple choice questions (MCQs) about '{subtopic}' "
                  "For each question, provide 4 options. Start the question with 'qstn:', options with 'opt:' with each option separated by comma, and the correct answer with 'ans:'. "
                  "Do not provide any other message or use any special characters or formatting unless necessary in questions. Separate each question set with a newline. Put a question and its options and answer in a single line with only space separating.")


        # Generate content using the Google Generative AI model
        response = model.generate_content(prompt)
        generated_content = response.text

        # Split the generated content by newline to separate each question
        questions_and_options = generated_content.split('\n')
        mcqs = []

        # Process each question
        for q in questions_and_options:
            try:
                if 'qstn:' in q and 'opt:' in q and 'ans:' in q:
                    question_part = q.split('qstn:', 1)[1].split('opt:', 1)[0].strip()
                    options_part = q.split('opt:', 1)[1].split('ans:', 1)[0].strip()
                    answer_part = q.split('ans:', 1)[1].strip()


                    options = options_part.split(',')

                    mcqs.append({
                        'question': question_part,
                        'options': options,
                        'correct_answer': answer_part
                    })
            except Exception as e:
                print(f"Error processing question: {e}")

        #if not mcqs:
          #  return jsonify({'error': 'No valid questions generated'}), 500

        return jsonify({'mcqs': mcqs})

    except Exception as e:
        return jsonify({'error': f'Failed to generate content: {str(e)}'}), 500



if __name__ == '__main__':
    app.run(debug=True)
