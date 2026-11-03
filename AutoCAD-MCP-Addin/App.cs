using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows.Media.Imaging;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;

namespace AutoCADMCP
{
    public class App : IExtensionApplication
    {
        public static System.Threading.SynchronizationContext MainThreadContext { get; private set; }
        private static bool _ribbonInitialized = false;
        private static readonly string[] AddinTabNames = new string[] { "外掛程式", "增益集", "Add-ins", "Add Ins", "增益集(Add-ins)" };

        public void Initialize()
        {
            MainThreadContext = System.Threading.SynchronizationContext.Current;

            // Auto-start MCP server on port 8965
            try
            {
                Server.SocketServer.Start();
            }
            catch (System.Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MCP] Auto-start server failed: {ex.Message}");
            }

            // Hook all possible events to guarantee Ribbon initialization across workspaces and startup modes
            if (ComponentManager.Ribbon != null)
            {
                TryInitRibbons();
            }
            else
            {
                ComponentManager.ItemInitialized += ComponentManager_ItemInitialized;
            }

            Application.Idle += Application_Idle;
            Application.DocumentManager.DocumentActivated += DocumentManager_DocumentActivated;
            Application.SystemVariableChanged += Application_SystemVariableChanged;

            LogEditor("\n[MCP] AutoCAD MCP Tools & Send2Rvt Loaded (Port 8965).\n");
        }

        public void Terminate()
        {
            try
            {
                Application.Idle -= Application_Idle;
                Application.DocumentManager.DocumentActivated -= DocumentManager_DocumentActivated;
                Application.SystemVariableChanged -= Application_SystemVariableChanged;
                ComponentManager.ItemInitialized -= ComponentManager_ItemInitialized;
                Server.SocketServer.Stop();
            }
            catch { }
        }

        private void ComponentManager_ItemInitialized(object sender, RibbonItemEventArgs e)
        {
            TryInitRibbons();
        }

        private void Application_Idle(object sender, EventArgs e)
        {
            if (ComponentManager.Ribbon != null)
            {
                TryInitRibbons();
            }
        }

        private void DocumentManager_DocumentActivated(object sender, DocumentCollectionEventArgs e)
        {
            if (ComponentManager.Ribbon != null)
            {
                TryInitRibbons();
            }
        }

        private void Application_SystemVariableChanged(object sender, SystemVariableChangedEventArgs e)
        {
            if (string.Equals(e.Name, "WSCURRENT", StringComparison.OrdinalIgnoreCase))
            {
                _ribbonInitialized = false;
                Application.Idle += Application_Idle;
            }
        }

        private void TryInitRibbons()
        {
            if (_ribbonInitialized) return;

            try
            {
                RibbonControl ribbon = ComponentManager.Ribbon;
                if (ribbon == null) return;

                bool mcpOk = CreateMcpRibbon(ribbon);
                bool sendOk = EnsureSend2RvtButton(ribbon);

                if (mcpOk && sendOk)
                {
                    _ribbonInitialized = true;
                    Application.Idle -= Application_Idle;
                    ComponentManager.ItemInitialized -= ComponentManager_ItemInitialized;
                }
            }
            catch (System.Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[MCP] Ribbon creation error: {ex.Message}");
            }
        }

        private static BitmapSource CreatePlayIcon(int size)
        {
            try
            {
                var visual = new System.Windows.Media.DrawingVisual();
                using (var dc = visual.RenderOpen())
                {
                    // Green rounded background
                    var bgBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(39, 174, 96));
                    bgBrush.Freeze();
                    dc.DrawRoundedRectangle(bgBrush, null, new System.Windows.Rect(1, 1, size - 2, size - 2), 4, 4);

                    // White play triangle
                    var fgBrush = System.Windows.Media.Brushes.White;
                    var path = new System.Windows.Media.PathGeometry();
                    var figure = new System.Windows.Media.PathFigure
                    {
                        StartPoint = new System.Windows.Point(size * 0.35, size * 0.25),
                        IsClosed = true,
                        IsFilled = true
                    };
                    figure.Segments.Add(new System.Windows.Media.LineSegment(new System.Windows.Point(size * 0.75, size * 0.5), true));
                    figure.Segments.Add(new System.Windows.Media.LineSegment(new System.Windows.Point(size * 0.35, size * 0.75), true));
                    path.Figures.Add(figure);
                    path.Freeze();
                    dc.DrawGeometry(fgBrush, null, path);
                }
                var rtb = new RenderTargetBitmap(size, size, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
                rtb.Render(visual);
                rtb.Freeze();
                return rtb;
            }
            catch
            {
                return null;
            }
        }

        private static BitmapSource CreateStopIcon(int size)
        {
            try
            {
                var visual = new System.Windows.Media.DrawingVisual();
                using (var dc = visual.RenderOpen())
                {
                    // Red rounded background
                    var bgBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(231, 76, 60));
                    bgBrush.Freeze();
                    dc.DrawRoundedRectangle(bgBrush, null, new System.Windows.Rect(1, 1, size - 2, size - 2), 4, 4);

                    // White stop square
                    var fgBrush = System.Windows.Media.Brushes.White;
                    double offset = size * 0.28;
                    double rectSize = size - 2 * offset;
                    dc.DrawRoundedRectangle(fgBrush, null, new System.Windows.Rect(offset, offset, rectSize, rectSize), 2, 2);
                }
                var rtb = new RenderTargetBitmap(size, size, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
                rtb.Render(visual);
                rtb.Freeze();
                return rtb;
            }
            catch
            {
                return null;
            }
        }

        private static BitmapSource CreateSendToRvtIcon(int size)
        {
            try
            {
                var visual = new System.Windows.Media.DrawingVisual();
                using (var dc = visual.RenderOpen())
                {
                    // Dark teal background (#1F7A8C / rgb(31, 122, 140))
                    var bgBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(31, 122, 140));
                    bgBrush.Freeze();
                    double cornerRadius = size * 0.18;
                    dc.DrawRoundedRectangle(bgBrush, null, new System.Windows.Rect(1, 1, size - 2, size - 2), cornerRadius, cornerRadius);

                    // White play triangle pointing right
                    var fgBrush = System.Windows.Media.Brushes.White;
                    double pad = size * 0.26;
                    var path = new System.Windows.Media.PathGeometry();
                    var figure = new System.Windows.Media.PathFigure
                    {
                        StartPoint = new System.Windows.Point(pad, size * 0.22),
                        IsClosed = true,
                        IsFilled = true
                    };
                    figure.Segments.Add(new System.Windows.Media.LineSegment(new System.Windows.Point(size - pad, size * 0.5), true));
                    figure.Segments.Add(new System.Windows.Media.LineSegment(new System.Windows.Point(pad, size * 0.78), true));
                    path.Figures.Add(figure);
                    path.Freeze();
                    dc.DrawGeometry(fgBrush, null, path);
                }
                var rtb = new RenderTargetBitmap(size, size, 96, 96, System.Windows.Media.PixelFormats.Pbgra32);
                rtb.Render(visual);
                rtb.Freeze();
                return rtb;
            }
            catch
            {
                return null;
            }
        }

        private bool CreateMcpRibbon(RibbonControl ribbon)
        {
            try
            {
                string tabId = "MCP_TAB";
                RibbonTab tab = ribbon.FindTab(tabId);

                if (tab == null)
                {
                    tab = new RibbonTab
                    {
                        Id = tabId,
                        Title = "MCP Tools"
                    };
                    ribbon.Tabs.Add(tab);

                    RibbonPanelSource panelSource = new RibbonPanelSource
                    {
                        Title = "Connection"
                    };
                    RibbonPanel panel = new RibbonPanel
                    {
                        Source = panelSource
                    };
                    tab.Panels.Add(panel);

                    var playIcon32 = CreatePlayIcon(32);
                    var playIcon16 = CreatePlayIcon(16);
                    var stopIcon32 = CreateStopIcon(32);
                    var stopIcon16 = CreateStopIcon(16);

                    RibbonButton btnStart = new RibbonButton
                    {
                        Text = "Start Server",
                        ShowText = true,
                        ShowImage = playIcon32 != null,
                        LargeImage = playIcon32,
                        Image = playIcon16,
                        Size = RibbonItemSize.Large,
                        Orientation = System.Windows.Controls.Orientation.Vertical,
                        CommandHandler = new RelayCommand(_ => Server.SocketServer.Start())
                    };

                    RibbonButton btnStop = new RibbonButton
                    {
                        Text = "Stop Server",
                        ShowText = true,
                        ShowImage = stopIcon32 != null,
                        LargeImage = stopIcon32,
                        Image = stopIcon16,
                        Size = RibbonItemSize.Large,
                        Orientation = System.Windows.Controls.Orientation.Vertical,
                        CommandHandler = new RelayCommand(_ => Server.SocketServer.Stop())
                    };

                    RibbonRowPanel row = new RibbonRowPanel();
                    row.Items.Add(btnStart);
                    row.Items.Add(btnStop);
                    panel.Source.Items.Add(row);
                }

                return true;
            }
            catch (System.Exception ex)
            {
                LogEditor($"\n[MCP] Error creating MCP tab: {ex.Message}\n");
                return false;
            }
        }

        private bool EnsureSend2RvtButton(RibbonControl ribbon)
        {
            try
            {
                // Send2Rvt is provided natively by Send2Rvt.AutoCad.bundle.
                // We ensure there is at most ONE Send2Rvt panel in the Add-ins tab.
                foreach (RibbonTab t in ribbon.Tabs)
                {
                    if (t.Title != null && AddinTabNames.Any(name => string.Equals(t.Title.Trim(), name, StringComparison.OrdinalIgnoreCase)))
                    {
                        var send2rvtPanels = new List<RibbonPanel>();
                        foreach (var p in t.Panels)
                        {
                            if (p?.Source == null) continue;
                            bool isSend2Rvt =
                                string.Equals(p.Source.Id, "Send2RvtPanel", StringComparison.OrdinalIgnoreCase) ||
                                string.Equals(p.Source.Title?.Trim(), "Send2Rvt", StringComparison.OrdinalIgnoreCase) ||
                                p.Source.Items.Any(item =>
                                    string.Equals(item.Id, "btnSend2Rvt_MCP", StringComparison.OrdinalIgnoreCase) ||
                                    (item.Text != null && item.Text.Contains("傳送至")) ||
                                    (item is RibbonButton rb && rb.CommandParameter?.ToString()?.Trim() == "SEND2RVT"));

                            if (isSend2Rvt)
                            {
                                send2rvtPanels.Add(p);
                            }
                        }

                        // If multiple Send2Rvt panels exist, keep only the first valid one and remove duplicates
                        if (send2rvtPanels.Count > 1)
                        {
                            for (int i = 1; i < send2rvtPanels.Count; i++)
                            {
                                t.Panels.Remove(send2rvtPanels[i]);
                            }
                            LogEditor($"\n[MCP] Deduplicated Send2Rvt panels: removed {send2rvtPanels.Count - 1} extra panel(s).\n");
                        }
                    }
                }
                return true;
            }
            catch (System.Exception ex)
            {
                LogEditor($"\n[MCP] Ribbon cleanup notice: {ex.Message}\n");
                return true;
            }
        }

        [CommandMethod("STARTMCP")]
        public void StartMcpCommand()
        {
            TryInitRibbons();
            Server.SocketServer.Start();
        }

        [CommandMethod("STOPMCP")]
        public void StopMcpCommand()
        {
            Server.SocketServer.Stop();
        }

        [CommandMethod("MCPRIBBON")]
        public void ShowRibbonCommand()
        {
            _ribbonInitialized = false;
            TryInitRibbons();
        }

        private static void LogEditor(string msg)
        {
            try
            {
                var doc = Application.DocumentManager?.MdiActiveDocument;
                if (doc != null)
                {
                    doc.Editor.WriteMessage(msg);
                }
            }
            catch { }
        }
    }

    public class RelayCommand : System.Windows.Input.ICommand
    {
        private readonly Action<object> _execute;
        public RelayCommand(Action<object> execute) { _execute = execute; }
        public bool CanExecute(object parameter) => true;
        public void Execute(object parameter) => _execute(parameter);
        public event EventHandler CanExecuteChanged { add { } remove { } }
    }
}
