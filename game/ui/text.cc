#include "text.hh"
#include "graphiccontext.hh"

Text::Text(std::string const& text)
: m_text(text)
{
}

void Text::setText(std::string const& text) {
	m_text = text;

	if(m_gc && !m_svg)
		m_svg = m_gc->makeSvgText(text);
}

std::string Text::getText() const {
	return m_text;
}

void Text::bind(GraphicContext& gc) {
	m_gc = &gc;

	m_svg = gc.makeSvgText(m_text);
}

void Text::draw(float x, float y) {
	m_svg->dimensions.left(x).top(y);
	m_svg->draw(m_gc->getWindow(), m_text);
}

void Text::draw(float x, float y, float width, float height) {
	m_svg->dimensions.left(x).center(y + height * 0.5);
	m_svg->setAlign(SvgTxtTheme::Align::LEFT);
	m_svg->draw(m_gc->getWindow(), m_text);
}

void Text::drawCentered(float x, float y, float width, float height) {
	m_svg->dimensions.middle(x + width * 0.5).center(y + height * 0.5);
	m_svg->setAlign(SvgTxtTheme::Align::CENTER);
	m_svg->draw(m_gc->getWindow(), m_text);
}
/*
float Text::measureWidth(std::string const& text) const {
	return m_svq->measure(text);
}

float Text::measureHeight(std::string const& text) const {
	auto result = 0.f;

	for (size_t i = 0; i < text.size(); ++i)
		result = std::max(result, m_opengl_text[i]->y());

	return result;
}
*/