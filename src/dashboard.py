"""Egregore Dashboard - Interactive Graph Visualization."""

import pandas as pd
import streamlit as st
from agraph import Config, Edge, Node, agraph

from src.graph_client import GraphClient, get_graph_client

# Page configuration
st.set_page_config(
    page_title="Egregore Dashboard",
    page_icon="🐝",
    layout="wide",
    initial_sidebar_state="expanded",
)


def init_session_state():
    """Initialize session state variables."""
    if "client" not in st.session_state:
        st.session_state.client = get_graph_client()
    if "refresh" not in st.session_state:
        st.session_state.refresh = False


def render_header():
    """Render the dashboard header."""
    col1, col2 = st.columns([6, 1])
    with col1:
        st.title("🐝 Egregore Dashboard")
        st.markdown("*Visualize and manage your Hive Mind memory*")
    with col2:
        if st.button("🔄 Refresh", use_container_width=True):
            st.session_state.refresh = True
            st.rerun()


def render_statistics(client: GraphClient):
    """Render statistics cards."""
    stats = client.get_statistics()

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.metric("🧠 Memories", stats.get("memory_count", 0))
    with col2:
        st.metric("🔗 Relations", stats.get("relation_count", 0))
    with col3:
        st.metric("📊 Density", f"{stats.get('density', 0):.4f}")
    with col4:
        st.metric("🏷️ Relation Types", stats.get("unique_relations", 0))


def render_graph_visualization(client: GraphClient):
    """Render the interactive graph visualization."""
    st.subheader("🕸️ Memory Graph")

    # Get data
    memories = client.get_all_memories()
    relationships = client.get_all_relationships()

    if not memories:
        st.info("No memories found. Add some memories to see the graph!")
        return

    # Create nodes
    nodes = []
    for mem in memories:
        node_id = mem.get("id", "unknown")
        # Truncate data for display
        data = mem.get("data", "")
        label = data[:30] + "..." if len(data) > 30 else data

        nodes.append(
            Node(
                id=node_id,
                label=label,
                title=data,  # Tooltip
                size=20,
                color="#00C49A" if "bugfix" in str(mem.get("metadata", "")) else "#0088FE",
            )
        )

    # Create edges
    edges = []
    for rel in relationships:
        edges.append(
            Edge(
                source=rel.get("source"),
                target=rel.get("target"),
                label=rel.get("type", "RELATED_TO"),
                color="#888888",
            )
        )

    # Graph configuration
    config = Config(
        width="100%",
        height=500,
        directed=True,
        physics=True,
        hierarchical=False,
        nodeHighlightBehavior=True,
        highlightColor="#F7C331",
        collapsible=False,
    )

    # Render graph
    agraph(nodes=nodes, edges=edges, config=config)


def render_add_memory(client: GraphClient):
    """Render form to add new memory."""
    st.subheader("➕ Add Memory")

    with st.form("add_memory_form"):
        data = st.text_area("Memory Content", height=100)
        col1, col2 = st.columns(2)
        with col1:
            context = st.selectbox(
                "Context",
                ["", "bugfix", "architecture", "preference", "configuration", "learning"],
            )
        with col2:
            tags = st.text_input("Tags (comma-separated)")

        submitted = st.form_submit_button("Add Memory", use_container_width=True)

        if submitted and data:
            metadata = {}
            if context:
                metadata["context"] = context
            if tags:
                metadata["tags"] = [t.strip() for t in tags.split(",") if t.strip()]

            try:
                memory_id = client.create_memory(data, metadata)
                st.success(f"Memory created! ID: {memory_id[:8]}...")
                st.session_state.refresh = True
            except Exception as e:
                st.error(f"Error creating memory: {e}")


def render_add_relation(client: GraphClient):
    """Render form to add relationship."""
    st.subheader("🔗 Add Relationship")

    memories = client.get_all_memories()
    if len(memories) < 2:
        st.info("Need at least 2 memories to create a relationship.")
        return

    memory_options = {m["id"]: f"{m['data'][:40]}..." for m in memories}

    with st.form("add_relation_form"):
        col1, col2 = st.columns(2)
        with col1:
            source_id = st.selectbox(
                "From Memory",
                options=list(memory_options.keys()),
                format_func=lambda x: memory_options.get(x, x),
            )
        with col2:
            target_id = st.selectbox(
                "To Memory",
                options=list(memory_options.keys()),
                format_func=lambda x: memory_options.get(x, x),
            )

        rel_type = st.selectbox(
            "Relationship Type",
            ["RELATED_TO", "DEPENDS_ON", "FIXES", "IMPLEMENTS", "REFERENCES"],
        )

        submitted = st.form_submit_button("Add Relationship", use_container_width=True)

        if submitted:
            if source_id == target_id:
                st.error("Cannot create relationship to the same memory!")
            else:
                try:
                    success = client.create_relationship(source_id, target_id, rel_type)
                    if success:
                        st.success("Relationship created!")
                        st.session_state.refresh = True
                    else:
                        st.error("Failed to create relationship.")
                except Exception as e:
                    st.error(f"Error: {e}")


def render_memory_list(client: GraphClient):
    """Render the memory list table."""
    st.subheader("📋 Memory List")

    # Search
    search_query = st.text_input("🔍 Search memories", "")

    if search_query:
        memories = client.search_memories(search_query)
    else:
        memories = client.get_all_memories()

    if not memories:
        st.info("No memories found.")
        return

    # Convert to DataFrame for display
    df_data = []
    for mem in memories:
        df_data.append({
            "ID": mem.get("id", "")[:8] + "...",
            "Content": mem.get("data", "")[:100] + "...",
            "Created": mem.get("created_at", "")[:19],
            "Metadata": str(mem.get("metadata", ""))[:50],
        })

    df = pd.DataFrame(df_data)
    st.dataframe(df, use_container_width=True, hide_index=True)

    # Delete memory section
    st.subheader("🗑️ Delete Memory")
    memory_options = {m["id"]: f"{m['data'][:50]}..." for m in memories}

    col1, col2 = st.columns([3, 1])
    with col1:
        to_delete = st.selectbox(
            "Select memory to delete",
            options=list(memory_options.keys()),
            format_func=lambda x: memory_options.get(x, x),
            key="delete_select",
        )
    with col2:
        if st.button("Delete", use_container_width=True, type="primary"):
            try:
                success = client.delete_memory(to_delete)
                if success:
                    st.success("Memory deleted!")
                    st.session_state.refresh = True
                else:
                    st.error("Failed to delete.")
            except Exception as e:
                st.error(f"Error: {e}")


def main():
    """Main dashboard application."""
    init_session_state()
    client = st.session_state.client

    render_header()

    # Statistics
    render_statistics(client)

    st.divider()

    # Main content in tabs
    tab1, tab2, tab3 = st.tabs(["🕸️ Graph View", "➕ Add Content", "📋 List View"])

    with tab1:
        render_graph_visualization(client)

    with tab2:
        col1, col2 = st.columns(2)
        with col1:
            render_add_memory(client)
        with col2:
            render_add_relation(client)

    with tab3:
        render_memory_list(client)

    # Footer
    st.divider()
    st.caption("Egregore Dashboard v0.1.0 - Hive Mind Memory System")


if __name__ == "__main__":
    main()
